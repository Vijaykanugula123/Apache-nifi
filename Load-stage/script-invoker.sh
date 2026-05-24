import org.apache.nifi.processor.io.StreamCallback
import org.apache.nifi.processor.io.OutputStreamCallback
import org.apache.nifi.processors.script.ExecuteScript
import org.apache.nifi.components.PropertyDescriptor

// Get the current flow file
def flowFile = session.get()
if (flowFile == null) {
    return
}

try {
    // 1. Extract access_token from 'set-cookie' attribute
    def setCookieHeader = flowFile.getAttribute('set-cookie')
    if (!setCookieHeader) {
        log.error("Access token not found in 'set-cookie' attribute. Cannot proceed.")
        session.transfer(flowFile, REL_FAILURE)
        return
    }

    // 2. Get Tenant ID from environment variable
    def tenantId = System.getenv("modenik_tid")
    if (!tenantId) {
        log.error("Tenant ID (modenik_tid environment variable) not found. Cannot proceed.")
        session.transfer(flowFile, REL_FAILURE)
        return
    }

    // 3. Determine BU ID based on 'bu.name' attribute
    def buName = flowFile.getAttribute('bu.name')
    def buId = ''
    if (buName == 'client1') {
        buId = System.getenv("client1_buid")
        if (!buId) {
            log.error("BU ID (client1_buid environment variable) not found for client1. Cannot proceed.")
            session.transfer(flowFile, REL_FAILURE)
            return
        }
    } else if (buName == 'client2') {
        buId = System.getenv("client2_buid")
        if (!buId) {
            log.error("BU ID (client2_buid environment variable) not found for client2. Cannot proceed.")
            session.transfer(flowFile, REL_FAILURE)
            return
        }
    } else {
        log.error("Unknown 'bu.name': ${buName}. Cannot determine BU ID.")
        session.transfer(flowFile, REL_FAILURE)
        return
    }

    // 4. Get filename from 'filename' attribute
    def filename = flowFile.getAttribute('filename')
    if (!filename) {
        log.error("Filename attribute not found. Cannot proceed.")
        session.transfer(flowFile, REL_FAILURE)
        return
    }

    // Construct the command
    def command = ['/opt/nifi/nifi-current/nifi_scripts/LoadStage/ash.sh', setCookieHeader, tenantId, buId, filename]

    log.info("Executing command: ${command.join(' ')}")

    // Execute the shell script
    def processBuilder = new ProcessBuilder(command)
    def process = processBuilder.start()

    // Capture output and error streams
    def stdout = new StringBuilder()
    def stderr = new StringBuilder()

    // Read streams in separate threads to prevent deadlocks
    def stdoutReader = new Thread({
        process.inputStream.eachLine { line -> stdout.append(line).append('\n') }
    })
    def stderrReader = new Thread({
        process.errorStream.eachLine { line -> stderr.append(line).append('\n') }
    })

    stdoutReader.start()
    stderrReader.start()

    stdoutReader.join() // Wait for stdout to be fully read
    stderrReader.join() // Wait for stderr to be fully read

    def exitCode = process.waitFor() // Wait for the process to complete

    // Write the script's stdout to the flowfile content regardless of success or failure
    flowFile = session.write(flowFile, { outputStream ->
        outputStream.write(stdout.toString().getBytes("UTF-8"))
    } as OutputStreamCallback)
    flowFile = session.putAttribute(flowFile, "mime.type", "text/plain")
    flowFile = session.putAttribute(flowFile, 'script.output', stdout.toString()) // Always add full stdout to attribute

    // Trim whitespace from stdout for accurate comparison
    def trimmedStdout = stdout.toString().trim()

    if (exitCode == 0) {
        // Script executed successfully, now check its output content
        if (trimmedStdout.contains("SUCCESS_WITHOUT_ROW_FAILURE")) {
            log.info("Script 'ash.sh' executed successfully with expected output: ${trimmedStdout}")
            session.transfer(flowFile, REL_SUCCESS)
        } else {
            // Script executed successfully, but output was not "SUCCESS_WITHOUT_ROW_FAILURE"
            // log.error("Script 'ash.sh' executed successfully but returned unexpected output: '${trimmedStdout}'. Routing to failure.")
            flowFile = session.putAttribute(flowFile, 'script.output.unexpected', trimmedStdout)
            flowFile = session.putAttribute(flowFile, 'script.error', stderr.toString()) // Keep stderr for context
            session.transfer(flowFile, REL_FAILURE)
        }
    } else {
        // Script itself failed with a non-zero exit code
        log.error("Script 'ash.sh' failed with exit code ${exitCode}. Error:\n${stderr.toString()}")
        flowFile = session.putAttribute(flowFile, 'script.error', stderr.toString())
        session.transfer(flowFile, REL_FAILURE)
    }

} catch (e) {
    log.error("Error processing flow file: ${e.message}", e)
    session.transfer(flowFile, REL_FAILURE)
}

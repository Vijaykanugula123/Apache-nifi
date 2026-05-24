import java.text.SimpleDateFormat
import java.util.Date

// Define the relationships for routing
// No longer needed to define these as they are typically injected by NiFi
// These lines are commented out because REL_SUCCESS and REL_FAILURE are usually
// available directly in the script's scope if configured in the processor's settings.
// def REL_SUCCESS = session.getRelationshipByName("success") // REMOVED/COMMENTED OUT
// def REL_FAILURE = session.getRelationshipByName("failure") // REMOVED/COMMENTED OUT


def flowFiles = session.get(100)
if (!flowFiles) return

// Define the date format expected from file.lastModifiedTime
// Note: 'Z' for timezone offset like +0000 or -0500
// If your timestamp includes milliseconds, use 'yyyy-MM-dd'T'HH:mm:ss.SSSZ'
def dateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ")

// Sort by file.lastModifiedTime (descending)
flowFiles.sort { a, b ->
    def timeA = 0L
    def timeB = 0L

    try {
        def dateStringA = a.getAttribute("file.lastModifiedTime")
        if (dateStringA) {
            timeA = dateFormat.parse(dateStringA).getTime() // Parse string to Date, then get milliseconds
        }
    } catch (e) {
        // Log the error and potentially route to failure if a timestamp cannot be parsed
        // Corrected: Changed getUUID() to getId()
        log.error("Failed to parse timestamp for FlowFile {}: {}. Error: {}", [a.getId(), a.getAttribute("file.lastModifiedTime"), e.getMessage()] as Object[])
        // Option 1: Treat as 0L (as in original script) - might affect sorting
        timeA = 0L
        // Option 2: Route this specific FlowFile to failure if parsing fails
        // session.transfer(a, REL_FAILURE)
        // return 0 // Return 0 to not affect sort order for other files
    }

    try {
        def dateStringB = b.getAttribute("file.lastModifiedTime")
        if (dateStringB) {
            timeB = dateFormat.parse(dateStringB).getTime() // Parse string to Date, then get milliseconds
        }
    } catch (e) {
        // Corrected: Changed getUUID() to getId()
        log.error("Failed to parse timestamp for FlowFile {}: {}. Error: {}", [b.getId(), b.getAttribute("file.lastModifiedTime"), e.getMessage()] as Object[])
        timeB = 0L
        // session.transfer(b, REL_FAILURE)
        // return 0
    }

    return timeB <=> timeA // Sort descending (latest first)
}

// Transfer only the latest
session.transfer(flowFiles[0], REL_SUCCESS)
// Corrected: Changed getUUID() to getId()
log.info("Transferred latest FlowFile {} with timestamp {}", [flowFiles[0].getId(), flowFiles[0].getAttribute("file.lastModifiedTime")] as Object[])


// Route older ones to failure instead of removing
flowFiles.drop(1).each {
    session.transfer(it, REL_FAILURE) // Changed from session.remove(it)
    log.info("Routed older FlowFile {} with timestamp {} to FAILURE", [it.getId(), it.getAttribute("file.lastModifiedTime")] as Object[])
}

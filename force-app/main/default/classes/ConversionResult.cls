global class ConversionResult {
    global Integer requestedCount = 0;
    global Integer convertedCount = 0;
    global Integer failedCount = 0;
    global List<String> convertedApplicationIds = new List<String>();
    global List<String> failedApplicationIds = new List<String>();
    global List<String> errors = new List<String>();
}

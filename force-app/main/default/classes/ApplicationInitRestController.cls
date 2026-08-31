@RestResource(urlMapping='/e2e/applications/init')
global with sharing class ApplicationInitRestController {
    @HttpPost
    global static CommandResult post() {
        try {
            String requestBody = RestContext.request.requestBody == null
                ? null
                : RestContext.request.requestBody.toString();
            InitApplicationCommand command = InitApplicationCommand.fromJson(requestBody);
            return new InitApplicationHandler().execute(command);
        } catch (Exception ex) {
            RestContext.response.statusCode = 400;
            return CommandResult.fail(ex.getMessage());
        }
    }
}

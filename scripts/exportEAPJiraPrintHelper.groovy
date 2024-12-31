
try {
    def config
    config = new ConfigSlurper().parse(new File(docDir, mainConfigFile).text)

    def stats = [:]
    def jira = new RESTClient(config.jiraAPI)
    jira.encoderRegistry = new EncoderRegistry(charset: 'utf-8')
    def headers = [
            'Authorization': 'Basic ' + config.jira.credentials,
            'Content-Type' : 'application/json; charset=utf-8'
    ]
    jira.get(path: 'search',
            query: ['jql'       : args[0],
                    'maxResults': 1000,
                    'fields'    : 'created,resolutiondate,priority,summary,timeoriginalestimate, assignee'
            ],
            headers: headers
    ).data.issues.each { issue ->
        print("${issue.key}")
        print("|${issue.fields.priority.name}")
        print("|${Date.parse("yyyy-MM-dd'T'H:m:s.000z", issue.fields.created).format('dd.MM.yy')}")
        print("|${issue.fields.assignee ? issue.fields.assignee.displayName : 'not assigned'}")
        print("|${issue.fields.summary}")
        println("|${config.jiraAPI - '/rest/api/2/'}/browse/${issue.key}")
    }
} catch (Exception e) {
    println e
}

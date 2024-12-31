package org.docToolchain.atlassian.jira.clients

import org.apache.hc.core5.http.ClassicHttpRequest
import org.docToolchain.configuration.ConfigService

abstract class JiraClient {

    protected RestClient restClient

    JiraClient(ConfigService configService) {
        this.restClient = new RestClient(configService)
    }

    protected callApiAndFailIfNot20x(ClassicHttpRequest httpRequest) {
        return restClient.doRequestAndFailIfNot20x(httpRequest)
    }

    abstract getIssuesByJql(String jql, String selectedFields)

    abstract getSprintsByBoardAndState(String boardId, String sprintState)

    abstract getIssuesForSprint(String boardId, Integer sprintId, String issueStatus, String ticketFields)

}

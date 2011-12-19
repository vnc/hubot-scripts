# Get all bugs from JIRA assigned to user
#
# To configure, export the following shell variables
# HUBOT_JIRA_DOMAIN
# HUBOT_JIRA_USER
# HUBOT_JIRA_PASSWORD
# HUBOT_JIRA_ISSUE_STATUSES
# HUBOT_JIRA_ISSUE_TYPES
# HUBOT_JIRA_ISSUE_PRIORITIES
#
# list [my] [<status>] [<priority> priority] bugs [about <searchterm>] - Retrieve a list of issues from JIRA that match the specified search criteria
#

# e.g. "bug|task|sub task|support ticket|new feature|epic"
issueTypes = process.env.HUBOT_JIRA_ISSUE_TYPES
issueTypes or= "bug|task|sub task|support ticket|new feature|epic|issue" #some defaults
                                                     
issueStatuses = process.env.HUBOT_JIRA_ISSUE_STATUSES
issueStatuses or= "assigned|blocked|open|closed|resolved|unresolved"

# e.g. "blocker|high|medium|minor|trivial"
issuePriorities = process.env.HUBOT_JIRA_ISSUE_PRIORITIES
issuePriorities or= "blocker|high|medium|minor|trivial" #some defaults

# /list( my)?(?: (closed|open|resolved))?(?: (blocker|high|medium|minor|trivial) priority)? (bug|task|sub task|support ticket|new feature|epic|issue)s(?: about (.*))?/i
regexpString = "list( my)?(?: (" + issueStatuses + "))?(?: (" + 
			   issuePriorities + ") priority)? (" + 
			   issueTypes + ")s(?: about (.*))?"      
regexp = new RegExp(regexpString, "i")

module.exports = (robot) ->

    robot.respond regexp, (msg) ->
        username = if msg.match[1] and msg.match[1] != "" then msg.message.user.email.split('@')[1] else null
        status = if msg.match[2] and msg.match[2] != "" then msg.match[2] else null
        priority = if msg.match[3] and msg.match[3] != "" then msg.match[3] else null
        issueType = if msg.match[4] and msg.match[4] != "issue" then msg.match[4] else null
        msg.send "Searching for issues..."
        getIssues msg, issueType, username, status, priority, msg.match[5], (response) ->
            msg.send response

getIssues = (msg, issueType, assignee, status, priority, phrase, callback) ->
    username = process.env.HUBOT_JIRA_USER
    password = process.env.HUBOT_JIRA_PASSWORD
    domain = process.env.HUBOT_JIRA_DOMAIN

    # do some error handling
    unless username
        msg.send "HUBOT_JIRA_USER environment variable must be set to a valid JIRA user's username."
        return
    unless password
        msg.send "HUBOT_JIRA_PASSWORD environment variable must be set to a valid JIRA user's password."
        return
    unless domain
        msg.send "HUBOT_JIRA_DOMAIN environment variables must be set to a valid <ORG>.jira.com domain."
        return

    jiraTypeList = toJiraTypeList(process.env.HUBOT_JIRA_ISSUE_TYPES.split('|'))
    type = if issueType? then 'issueType="' + issueType + '"' else 'issueType in (' + jiraTypeList + ')'
    user = if assignee? then ' and assignee="' + assignee + '"' else ''
    prio = if priority? then ' and priority=' + priority else ''  
    stat = if status? then ' and status=' + status else ' and status!=closed'
    search = if phrase? then ' and (summary~"' + phrase + '" or description~"' + phrase + '")' else ''

    path = '/rest/api/latest/search'
    url = "https://" + domain + path
    queryString = type + stat + user + prio + search
    auth = "Basic " + new Buffer(username + ':' + password).toString('base64')

    getJSON msg, url, queryString, auth, (err, json) ->
        if err
            msg.send "error getting issue list from JIRA"
            return
        if json.total? and (json.total==0 or json.total=="0")
            msg.send "No issues like that, or you don't have access to see the issues."
        issueList = []
        for issue in json.issues
            getJSON msg, issue.self, null, auth, (err, details) ->
                if err
                    msg.send "error getting issue details from JIRA"
                    return
                issueList.push( {key: details.key, summary: details.fields.summary.value} )
                callback(formatIssueList(issueList, domain)) if issueList.length == json.issues.length

formatIssueList = (issueArray, domain) ->
    formattedIssueList = ""
    for issue in issueArray
        formattedIssueList += issue.summary + " -> https://" + domain + "/browse/" + issue.key + "\n"
    return formattedIssueList

getJSON = (msg, url, query, auth, callback) ->
    msg.http(url)
        .header('Authorization', auth)
        .query(jql: query)
        .get() (err, res, body) ->
            callback( err, JSON.parse(body) )

toJiraTypeList = (arr) ->
    newArr = []
    for issueType in arr
        newArr.push '"' + issueType + '"'
    return newArr.join(',')

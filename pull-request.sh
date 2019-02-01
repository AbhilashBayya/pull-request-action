#!/bin/bash

# Suggested by Github actions to be strict
set -e
set -o pipefail

################################################################################
# Global Variables (we can't use GITHUB_ prefix)
################################################################################

API_VERSION=v3
BASE=https://api.github.com
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
HEADER="Accept: application/vnd.github.${API_VERSION}+json"
HEADER="${HEADER}; application/vnd.github.antiope-preview+json"

# URLs
REPO_URL="${BASE}/repos/${GITHUB_REPOSITORY}"
PULLS_URL=$REPO_URL/pulls

################################################################################
# Helper Functions
################################################################################

get_url() {

    RESPONSE=$(curl -sSL -H "${AUTH_HEADER}" -H "${HEADER}" "${1:-}")
    echo ${RESPONSE}
}

check_credentials() {

    if [[ -z "${GITHUB_TOKEN}" ]]; then
        echo "You must include the GITHUB_TOKEN as an environment variable."
        exit 1
    fi

}

check_events_json() {

    if [[ ! -f "${GITHUB_EVENT_PATH}" ]]; then
        echo "Cannot find Github events file at ${GITHUB_EVENT_PATH}";
        exit 1;
    fi
    echo "Found ${GITHUB_EVENT_PATH}";
    cat "${GITHUB_EVENT_PATH}"

}

create_pull_request() {

    SOURCE=${1}  # from this branch
    TARGET=${2}  # pull request TO this target

    TITLE="Update container ${SOURCE}"
    BODY="This is an automated pull request to update the container collection ${SOURCE}"

    # Post the pull request
    curl -d "{\"title\":\"${TITLE}\", \"body\":\"${BODY}\", \"head\":\"${SOURCE}\", \"base\":\"${TARGET}\"}" -H "Content-Type: application/json" -H "\"${HEADER}\"" -H \""${AUTH_HEADER}"\" -X POST ${PULLS_URL};
    echo $?
}


main () {

    # path to file that contains the POST response of the event
    # Example: https://github.com/actions/bin/tree/master/debug
    # Value: /github/workflow/event.json
    check_events_json;

    # User specified branch to PR to, and check
    if [ -z "${BRANCH_PREFIX}" ]; then
        echo "No branch prefix is set, all branches will be used."
        BRANCH_PREFIX=""
    fi

    if [ -z "${PULL_REQUEST_BRANCH}" ]; then
        PULL_REQUEST_BRANCH=master
    fi
    echo "Pull requests will go to ${PULL_REQUEST_BRANCH}"

    # Get the name of the action that was triggered
    BRANCH=$(jq --raw-output .ref "${GITHUB_EVENT_PATH}");
    echo "Found branch $BRANCH"
 
    # If it's to the target branch, ignore it
    if [[ "${BRANCH}" == "${PULL_REQUEST_BRANCH}" ]]
        echo "Target and current branch are identical (${BRANCH}), skipping."
    else

        # If the prefix for the branch matches
        if  [[ $BRANCH == ${BRANCH_PREFIX}* ]]; then

            # Ensure we have a GitHub token
            check_credentials
            create_pull_request $BRANCH $PULL_REQUEST_BRANCH

        fi

    fi
}

echo "==========================================================================
START: Running Pull Request on Branch Update Action!";
main;
echo "==========================================================================
END: Finished";
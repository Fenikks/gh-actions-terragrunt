#!/bin/bash

# shellcheck source=../actions.sh
source /usr/local/actions.sh

debug
setup

set_common_plan_args

exec 3>&1

### Generate a plan
plan

echo "### output of $STEP_TMP_DIR/terraform_plan.stderr"
cat "$STEP_TMP_DIR/terraform_plan.stderr"

if [[ "$GITHUB_EVENT_NAME" == "pull_request" || "$GITHUB_EVENT_NAME" == "issue_comment" || "$GITHUB_EVENT_NAME" == "pull_request_review_comment" || "$GITHUB_EVENT_NAME" == "pull_request_target" || "$GITHUB_EVENT_NAME" == "pull_request_review" || "$GITHUB_EVENT_NAME" == "repository_dispatch" ]]; then
    if [[ "$INPUT_ADD_GITHUB_COMMENT" == "true" || "$INPUT_ADD_GITHUB_COMMENT" == "changes-only" ]]; then

        if [[ ! -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
            echo "GITHUB_TOKEN environment variable must be set to add GitHub PR comments"
            echo "Either set the GITHUB_TOKEN environment variable, or disable by setting the add_github_comment input to 'false'"
            echo "See https://github.com/dflook/terraform-github-actions/ for details."
            exit 1
        fi

        if ! STATUS=":memo: Plan generated in $(job_markdown_ref)" github_pr_comment plan; then
            exit 1
        fi

    fi

else
    debug_log "Not a pull_request, issue_comment, pull_request_target, pull_request_review, pull_request_review_comment or repository_dispatch event - not creating a PR comment"
fi

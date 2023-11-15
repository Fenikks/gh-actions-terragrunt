#!/bin/bash

# shellcheck source=../actions.sh
source /usr/local/actions.sh

echo "---------- DEBUG MESSAGE calling debug funcion ----------"
debug

echo "---------- DEBUG MESSAGE calling setup funcion ----------"
setup

echo "---------- DEBUG MESSAGE calling set_common_plan-args funcion ----------"
set_common_plan_args


if [[ -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
    echo "---------- DEBUG MESSAGE updating status in PR ----------"
    update_status ":orange_circle: Applying plan in $(job_markdown_ref)"
fi

exec 3>&1

echo "---------- DEBUG MESSAGE creating plan ----------"
### Generate a plan
plan


### Apply the plan

if [[ "$INPUT_AUTO_APPROVE" == "true" ]]; then
    echo "---------- DEBUG MESSAGE if autoapprove true ----------"
    echo "Automatically approving plan"
    apply

else

    if [[ "$GITHUB_EVENT_NAME" != "push" && "$GITHUB_EVENT_NAME" != "pull_request" && "$GITHUB_EVENT_NAME" != "issue_comment" && "$GITHUB_EVENT_NAME" != "pull_request_review_comment" && "$GITHUB_EVENT_NAME" != "pull_request_target" && "$GITHUB_EVENT_NAME" != "pull_request_review" && "$GITHUB_EVENT_NAME" != "repository_dispatch" ]]; then
        echo "---------- DEBUG MESSAGE if github event name is incorrect ----------"
        echo "Could not fetch plan from the PR - $GITHUB_EVENT_NAME event does not relate to a pull request. You can generate and apply a plan automatically by setting the auto_approve input to 'true'"
        exit 1
    fi

    if [[ ! -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
        echo "---------- DEBUG MESSAGE if github token not set ----------"
        echo "GITHUB_TOKEN environment variable must be set to get plan approval from a PR"
        echo "Either set the GITHUB_TOKEN environment variable or automatically approve by setting the auto_approve input to 'true'"
        echo "See https://github.com/dflook/terraform-github-actions/ for details."
        exit 1
    fi

echo "---------- DEBUG MESSAGE checking if plan is approved ----------"
    if github_pr_comment approved; then
        echo "---------- DEBUG MESSAGE applying plan ----------"
        # apply
        echo "Plan should be applied"
    else
        exit 1
    fi

fi

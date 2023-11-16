#!/bin/bash

# shellcheck source=../actions.sh
source /usr/local/actions.sh

debug
setup
set_common_plan_args

if [[ -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
    update_status ":orange_circle: Applying plan in $(job_markdown_ref)"
fi

exec 3>&1

### Generate a plan
plan

start_group "TEMP test aws"
echo "---------- DEBUG MESSAGE call aws cli ----------"
set +e

export AWS_REGION=us-east-1
env|grep AWS_SECRET_ACCESS_KEY
aws sts get-caller-identity
set -e
echo "--------------------------------------------"
end_group

# Check if state is locked
start_group "Output of terraform_plan.stderr"
echo "---------- DEBUG MESSAGE output of $STEP_TMP_DIR/terraform_plan.stderr ----------"
cat >&2 "$STEP_TMP_DIR/terraform_plan.stderr"
echo "--------------------------------------------"
end_group

if lock-info "$STEP_TMP_DIR/terraform_plan.stderr"; then
    update_status ":x: Error applying plan in $(job_markdown_ref)(State is locked)"
    exit 1
fi

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
        echo "Plan should be applied"
        apply
    else
        exit 1
    fi

fi

start_group "Output of terraform_apply.stderr"
echo "---------- DEBUG MESSAGE output of $STEP_TMP_DIR/terraform_apply.stderr after apply"
cat "$STEP_TMP_DIR/terraform_apply.stderr"
echo "--------------------------------------------"
end_group

start_group "Output of terraform_apply.stdout"
echo "---------- DEBUG MESSAGE output of $STEP_TMP_DIR/terraform_apply.stdout after apply"
cat "$STEP_TMP_DIR/terraform_apply.stdout"
echo "--------------------------------------------"
end_group

# check if there are errors in terraform_apply.stderr

if lock-info "$STEP_TMP_DIR/terraform_apply.stderr"; then
    update_status ":x: Error applying plan in $(job_markdown_ref)(State is locked)"
    exit 1
else
    for code in $(tac $STEP_TMP_DIR/terraform_apply.stderr | awk '/^[[:space:]]*\*/{flag=1; print} flag && /^[[:space:]]*time=/{exit}' | awk '{print $5}'); do
        echo "---------- DEBUG MESSAGE checking plan exit code ----------"
        echo "code is $code"
        if [[ $code -eq 1 ]]; then
            update_status ":x: Error applying plan in $(job_markdown_ref)"
            exit 1
        fi
    done
fi

update_status ":white_check_mark: Plan applied in $(job_markdown_ref)"

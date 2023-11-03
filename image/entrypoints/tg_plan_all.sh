#!/bin/bash

# shellcheck source=../actions.sh
source /usr/local/actions.sh

debug
setup

set-common-plan-args

exec 3>&1

### Generate a plan
#PLAN_OUT="$STEP_TMP_DIR/plan.out"
plan


cat "$STEP_TMP_DIR/terraform_plan.stderr"
debug_log "Checking if terragrunt plan finished with error"
debug_file "$STEP_TMP_DIR/terraform_plan.stderr"

if [ -e "$STEP_TMP_DIR/terraform_plan.stderr" && -s "$STEP_TMP_DIR/terraform_plan.stderr" ]; then
    debug_log "terragrunt plan finished with error"
else
    debug_log "terragrunt plan complites successfully"
fi

debug_log "Reading plans"
for plan in  $PLAN_OUT_DIR/plan-*;do
    echo $plan
    debug_file "$plan"
    cat $plan
done


if [[ "$GITHUB_EVENT_NAME" == "pull_request" || "$GITHUB_EVENT_NAME" == "issue_comment" || "$GITHUB_EVENT_NAME" == "pull_request_review_comment" || "$GITHUB_EVENT_NAME" == "pull_request_target" || "$GITHUB_EVENT_NAME" == "pull_request_review" || "$GITHUB_EVENT_NAME" == "repository_dispatch" ]]; then
    if [[ "$INPUT_ADD_GITHUB_COMMENT" == "true" || "$INPUT_ADD_GITHUB_COMMENT" == "changes-only" ]]; then

        if [[ ! -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
            echo "GITHUB_TOKEN environment variable must be set to add GitHub PR comments"
            echo "Either set the GITHUB_TOKEN environment variable, or disable by setting the add_github_comment input to 'false'"
            echo "See https://github.com/dflook/terraform-github-actions/ for details."
            exit 1
        fi

        if [[ $PLAN_EXIT -eq 1 ]]; then
            if ! STATUS=":x: Failed to generate plan in $(job_markdown_ref)" github_pr_comment plan <"$STEP_TMP_DIR/terraform_plan.stderr"; then
                exit 1
            fi

        else

            if [[ $PLAN_EXIT -eq 0 ]]; then
                TF_CHANGES=false
            else # [[ $PLAN_EXIT -eq 2 ]]
                TF_CHANGES=true
            fi

            if ! TF_CHANGES=$TF_CHANGES STATUS=":memo: Plan generated in $(job_markdown_ref)" github_pr_comment plan <"$STEP_TMP_DIR/plan.txt"; then
                exit 1
            fi
        fi

    fi

else
    debug_log "Not a pull_request, issue_comment, pull_request_target, pull_request_review, pull_request_review_comment or repository_dispatch event - not creating a PR comment"
fi

if [[ $PLAN_EXIT -eq 1 ]]; then
    debug_log "Error running terragrunt"
    exit 1

elif [[ $PLAN_EXIT -eq 0 ]]; then
    debug_log "No Changes to apply"
    set_output changes false

elif [[ $PLAN_EXIT -eq 2 ]]; then
    debug_log "Changes to apply"
    set_output changes true

    plan_summary "$STEP_TMP_DIR/plan.txt"
fi

mkdir -p "$GITHUB_WORKSPACE/$WORKSPACE_TMP_DIR"
cp "$STEP_TMP_DIR/plan.txt" "$GITHUB_WORKSPACE/$WORKSPACE_TMP_DIR/plan.txt"
set_output text_plan_path "$WORKSPACE_TMP_DIR/plan.txt"

if [[ -n "$PLAN_OUT" ]]; then
    if (cd "$INPUT_PATH" && terragrunt show -json "$PLAN_OUT") >"$GITHUB_WORKSPACE/$WORKSPACE_TMP_DIR/plan.json" 2>"$STEP_TMP_DIR/terraform_show.stderr"; then
        set_output json_plan_path "$WORKSPACE_TMP_DIR/plan.json"
    else
        debug_file "$STEP_TMP_DIR/terraform_show.stderr"
    fi
fi

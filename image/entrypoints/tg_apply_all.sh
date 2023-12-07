#!/bin/bash

# shellcheck source=../actions.sh
source /usr/local/actions.sh

debug
setup
set_common_plan_args

exec 3>&1

if [[ -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
    update_status ":orange_circle: Applying plan in $(job_markdown_ref)"
fi

### Generate a plan
plan

start_group "Content of terraform_plan.stderr"
cat >&2 "$STEP_TMP_DIR/terraform_plan.stderr"
end_group

start_group "Content of terraform_show_plan.stderr"
cat >&2 "$STEP_TMP_DIR/terraform_show_plan.stderr"
end_group

# Check if state is locked
if lock-info "$STEP_TMP_DIR/terraform_plan.stderr"; then
    update_status ":x: Error applying plan in $(job_markdown_ref)(State is locked)"
    exit 1
fi

### Apply the plan

if [[ "$INPUT_AUTO_APPROVE" == "true" ]]; then
    echo "Automatically approving plan"
    apply

else
    if [[ "$GITHUB_EVENT_NAME" != "push" && "$GITHUB_EVENT_NAME" != "pull_request" && "$GITHUB_EVENT_NAME" != "issue_comment" && "$GITHUB_EVENT_NAME" != "pull_request_review_comment" && "$GITHUB_EVENT_NAME" != "pull_request_target" && "$GITHUB_EVENT_NAME" != "pull_request_review" && "$GITHUB_EVENT_NAME" != "repository_dispatch" ]]; then
        echo "Could not fetch plan from the PR - $GITHUB_EVENT_NAME event does not relate to a pull request. You can generate and apply a plan automatically by setting the auto_approve input to 'true'"
        exit 1
    fi

    if [[ ! -v TERRAFORM_ACTIONS_GITHUB_TOKEN ]]; then
        echo "GITHUB_TOKEN environment variable must be set to get plan approval from a PR"
        echo "Either set the GITHUB_TOKEN environment variable or automatically approve by setting the auto_approve input to 'true'"
        echo "See https://github.com/dflook/terraform-github-actions/ for details."
        exit 1
    fi

    if github_pr_comment approved; then
        apply
    else
        exit 1
    fi
fi

# If there is no files in terraform_apply_error and in terraform_apply_stdout, then there is no changes in the plan
if [[ ! "$(ls $STEP_TMP_DIR/terraform_apply_error/*.stderr 2>/dev/null)" ]] && [[ ! "$(ls $STEP_TMP_DIR/terraform_apply_error/*.stdout 2>/dev/null)" ]]; then
    echo "No changes in the plan, skipping apply"
    update_status ":white_check_mark: Plan applied in $(job_markdown_ref)"
    exit 0
fi

start_group "Apply stderr"
for file in $STEP_TMP_DIR/terraform_apply_error/*; do
    start_group "${file#$INPUT_PATH//___/\/}"
    cat $file
    end_group
done
end_group

# start_group "Content of terraform_apply.stderr"
# cat $STEP_TMP_DIR/terraform_apply.stderr
# end_group

start_group "Apply stdout"
for file in $STEP_TMP_DIR/terraform_apply_stdout/*; do
    start_group "${file#$INPUT_PATH//___/\/}"
    cat $file
    end_group
done
end_group

# start_group "Content of terraform_apply.stdout"
# cat $STEP_TMP_DIR/terraform_apply.stdout
# end_group

# check if there are errors in terraform_apply.stderr

for file in $STEP_TMP_DIR/terraform_apply_error/*; do
    if lock-info "$file"; then
        update_status ":x: Error applying plan in $(job_markdown_ref)(State is locked)"
        exit 1
    else
        for code in $(tac $file | awk '/^[[:space:]]*\*/{flag=1; print} flag && /^[[:space:]]*time=/{exit}' | awk '{print $5}'); do
            if [[ $code -eq 1 ]]; then
                update_status ":x: Error applying plan in $(job_markdown_ref)"
                exit 1
            fi
        done
    fi
done

# if lock-info "$STEP_TMP_DIR/terraform_apply.stderr"; then
#     update_status ":x: Error applying plan in $(job_markdown_ref)(State is locked)"
#     exit 1
# else
#     for code in $(tac $STEP_TMP_DIR/terraform_apply.stderr | awk '/^[[:space:]]*\*/{flag=1; print} flag && /^[[:space:]]*time=/{exit}' | awk '{print $5}'); do
#         if [[ $code -eq 1 ]]; then
#             update_status ":x: Error applying plan in $(job_markdown_ref)"
#             exit 1
#         fi
#     done
# fi

update_status ":white_check_mark: Plan applied in $(job_markdown_ref)"

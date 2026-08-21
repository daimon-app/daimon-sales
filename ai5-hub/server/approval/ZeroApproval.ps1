function Get-AI5ZeroApprovalReview {
    param($Route)

    $checks = @('対象と操作種別を確認済み', 'AI5 HUBの本人承認が必要')
    $risks = @()
    $recommended = 'APPROVE'

    switch ([string]$Route.approvalType) {
        'OWNER_PUBLISH' { $risks += '一般ユーザーへ公開されます'; $checks += '公開先と公開内容を確認してください' }
        'OWNER_MONEY' { $risks += '料金・購入・契約が発生します'; $recommended = 'REJECT'; $checks += '金額と契約条件を確認してください' }
        'OWNER_IRREVERSIBLE' { $risks += '元に戻せない操作です'; $recommended = 'REJECT'; $checks += '復旧不能であることを確認してください' }
        'OWNER_IDENTITY' { $risks += '本人による認証または意思確認が必要です'; $recommended = 'REJECT'; $checks += 'CAPTCHA・2FA・本人確認は本人が操作してください' }
        default { $risks += '本人承認が必要な重要操作'; $recommended = 'REJECT' }
    }

    [ordered]@{
        verdict = $(if ($recommended -eq 'APPROVE') { 'APPROVAL_OK' } else { 'NOT_RECOMMENDED' })
        reason = $(if ($recommended -eq 'APPROVE') { '対象を限定したうえで本人承認後に続行可能です。' } else { '安全条件が確定するまで実行しないことを推奨します。' })
        risks = @($risks)
        checks = @($checks)
        recommended_action = $recommended
        reviewed_at = [DateTime]::UtcNow.ToString('o')
        is_human_approval = $false
    }
}

function New-AI5ApprovalEvidence {
    param($Task,[string]$Executor='zero',[string]$Verifier='codex')
    [ordered]@{request=[string]$Task.objective;classification=[string]$Task.route.approvalClass;risk_evaluation=$Task.route.riskEvaluation;executor=$Executor;test_result=@($Task.result.tests);verifier=$Verifier;approval_result=$(if($Task.requiresApproval){'OWNER_GATE'}else{'AI_APPROVED'});timestamp=[DateTime]::UtcNow.ToString('o');commit=[string]$Task.result.commitId;rollback_information=[string]$Task.route.riskEvaluation.rollback_method}
}

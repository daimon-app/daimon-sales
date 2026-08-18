function Get-AI5ZeroApprovalReview {
    param($Route)

    $checks = @('対象と操作種別を確認済み', 'AI5 HUBの本人承認が必要')
    $risks = @()
    $recommended = 'APPROVE'

    switch ([string]$Route.approvalType) {
        'external_publish' { $risks += '外部公開または本番公開を含む'; $checks += '公開範囲は実行直前に再確認する' }
        'payment' { $risks += '料金・購入・契約が発生する可能性'; $recommended = 'REJECT'; $checks += '金額と契約条件は未承認' }
        'destructive' { $risks += '削除または不可逆操作を含む'; $recommended = 'REJECT'; $checks += '復旧方法は実行前に必要' }
        'credential' { $risks += '認証情報またはアカウント変更を含む'; $recommended = 'REJECT'; $checks += '秘密情報はHUBへ入力しない' }
        'external_send' { $risks += '第三者への外部送信を含む'; $checks += '送信先と内容は本人確認が必要' }
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

function Invoke-AI5MockAdapter {
  param([Parameter(Mandatory=$true)]$Task)
  Start-Sleep -Milliseconds 350
  [ordered]@{
    status='completed'; summary="Mock施工が完了しました: $($Task.objective)";
    details=@("$($Task.assignedPrimary) が安全な疑似処理を実行",'Zeroが完了条件を照合');
    filesChanged=@(); tests=@('Mock adapter response: PASS'); warnings=@('実AI・外部サービスは使用していません'); needsApproval=$false
  }
}


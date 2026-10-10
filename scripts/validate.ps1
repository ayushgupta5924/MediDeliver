$ErrorActionPreference = 'Stop'
function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
  & $Executable @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Executable failed ($LASTEXITCODE)" }
}
Invoke-Checked flutter @('pub','get','--enforce-lockfile')
Invoke-Checked dart @('format','--output=none','--set-exit-if-changed','lib','test')
Invoke-Checked flutter @('analyze','--no-pub')
Invoke-Checked flutter @('test','--no-pub')
Invoke-Checked npm.cmd @('ci')
Invoke-Checked npm.cmd @('test')
Invoke-Checked node @('scripts/test_database.mjs')
Invoke-Checked flutter @('build','web','--release','--no-pub','--no-web-resources-cdn','--dart-define=SUPABASE_URL=https://example.supabase.co','--dart-define=SUPABASE_ANON_KEY=sb_publishable_ci_placeholder_not_a_real_key')
Write-Host 'Validation passed. The generated web build uses placeholder configuration; it is not a deployable production build.'

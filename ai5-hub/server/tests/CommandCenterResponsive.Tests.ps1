$ErrorActionPreference='Stop';$root=Split-Path (Split-Path $PSScriptRoot);$css=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'styles.css');$html=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'index.html');$app=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app.js')
if($css-notmatch'@media\(max-width: 680px\)'){throw 'mobile breakpoint missing'}
if($css-notmatch'grid-template-columns:repeat\(4,1fr\)'){throw 'four-column mobile navigation missing'}
if($css-match'\.bottom-nav\{grid-template-columns:repeat\(3,1fr\)'){throw 'mobile navigation wraps to a second row'}
if($css-notmatch'100dvh'-or$css-notmatch'safe-area-inset-bottom'){throw 'dynamic viewport or safe area missing'}
if($css-notmatch'\.composer\{position:relative;flex:0 0 auto'){throw 'composer bottom navigation protection missing'}
if($html-notmatch'data-view="ai5"'-or([regex]::Matches($html,'<button data-view=').Count-ne4)){throw '360px navigation contract failed'}
if($html-notmatch'viewport-fit=cover'){throw 'safe-area viewport missing'}
if($app-notmatch'function closeActivity\(\)' -or $app-notmatch'panel\.classList\.remove\("mobile-open"\)'){throw 'mobile activity close contract missing'}
if($app-notmatch'Promise\.all\(\[refreshTaskLists\(\),refreshCommandCenter\(\)\]\)' -or $app-notmatch'closeActivity\(\);zeroMessage'){throw 'approval immediate refresh contract missing'}
if($app-notmatch'button\.disabled=true' -or $app-notmatch'event\.target\.textContent=action'){throw 'approval duplicate-submit protection missing'}
if($css-notmatch'\.approval-row\{display:grid;grid-template-columns:112px' -or $css-notmatch'grid-template-columns:96px minmax\(0,1fr\)'){throw '412x915 compact approval context contract missing'}
if($css-notmatch'\.approval-card\{padding:10px\}' -or $css-notmatch'\.approval-card button\{min-height:44px'){throw 'mobile approval density contract missing'}
'COMMAND_CENTER_RESPONSIVE_TESTS_OK widths=360,390,412,430 contract'

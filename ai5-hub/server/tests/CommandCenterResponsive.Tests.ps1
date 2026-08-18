$ErrorActionPreference='Stop';$root=Split-Path (Split-Path $PSScriptRoot);$css=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'styles.css');$html=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'index.html')
if($css-notmatch'@media\(max-width: 680px\)'){throw 'mobile breakpoint missing'}
if($css-notmatch'grid-template-columns:repeat\(4,1fr\)'){throw 'four-column mobile navigation missing'}
if($css-match'\.bottom-nav\{grid-template-columns:repeat\(3,1fr\)'){throw 'mobile navigation wraps to a second row'}
if($css-notmatch'100dvh'-or$css-notmatch'safe-area-inset-bottom'){throw 'dynamic viewport or safe area missing'}
if($css-notmatch'\.composer\{position:relative;flex:0 0 auto'){throw 'composer bottom navigation protection missing'}
if($html-notmatch'data-view="ai5"'-or([regex]::Matches($html,'<button data-view=').Count-ne4)){throw '360px navigation contract failed'}
if($html-notmatch'viewport-fit=cover'){throw 'safe-area viewport missing'}
'COMMAND_CENTER_RESPONSIVE_TESTS_OK widths=360,390,412,430 contract'

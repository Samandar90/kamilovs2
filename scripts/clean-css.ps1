Param(
  [string]$HtmlPath = "index.html",
  [string]$CssPath = "css/style.css",
  [string]$ConservativeOut = "css/style.index.conservative.css",
  [string]$AggressiveOut = "css/style.index.aggressive.css"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Blocks([string]$css){
  $blocks = New-Object System.Collections.Generic.List[object]
  $i=0; $n=$css.Length; $depth=0; $start=0; $mode='find'; $insideString=$false; $strChar=''; $insideComment=$false
  while($i -lt $n){
    $ch = $css[$i]
    if($insideComment){ if($i+1 -lt $n -and $ch -eq '*' -and $css[$i+1] -eq '/'){ $insideComment=$false; $i+=2; continue } $i++; continue }
    if($insideString){ if($ch -eq $strChar){ $insideString=$false } elseif($ch -eq '\\'){ $i+=2; continue } $i++; continue }
    if($i+1 -lt $n -and $ch -eq '/' -and $css[$i+1] -eq '*'){ $insideComment=$true; $i+=2; continue }
    if($ch -eq '"' -or $ch -eq "'"){ $insideString=$true; $strChar=$ch; $i++; continue }

    if($mode -eq 'find'){
      if([char]::IsWhiteSpace($ch)){ $i++; continue }
      $start=$i; $mode='inblock'
    } else {
      if($ch -eq '{'){ $depth++ }
      elseif($ch -eq '}'){ $depth--; if($depth -lt 0){ $depth=0 } }
      if($depth -eq 0 -and $ch -eq '}'){
        $end = $i+1
        $text = $css.Substring($start, $end-$start)
        $selectorEnd = $css.IndexOf('{',$start)
        $selector = ''
        if($selectorEnd -ge 0 -and $selectorEnd -lt $end){
          $selector = $css.Substring($start, $selectorEnd-$start).Trim()
        }
        $blocks.Add([pscustomobject]@{ selector=$selector; text=$text })
        $mode='find'
      }
    }
    $i++
  }
  return $blocks
}

function Build-CSS([string]$cssPath,[string[]]$classes,[string[]]$ids,[string[]]$families,[string[]]$baseSelectors,[bool]$aggressive){
  $css = Get-Content -Raw $cssPath
  $blocks = Get-Blocks $css
  $classTokens = $classes | ForEach-Object { '.' + $_ }
  $idTokens = $ids | ForEach-Object { '#' + $_ }
  $tokens = @(); $tokens += $classTokens; $tokens += $idTokens; $tokens += $baseSelectors
  if(-not $aggressive){ $tokens += $families }
  $tokens = $tokens | Sort-Object -Unique

  $keep = New-Object System.Collections.Generic.List[string]
  foreach($b in $blocks){
    $sel = $b.selector
    $text = $b.text
    $s = $sel.TrimStart()
    if($s.StartsWith('@keyframes') -or $s.StartsWith('@font-face') -or $s.StartsWith('@-webkit-keyframes')){ $keep.Add($text); continue }
    if($s.StartsWith('@media')){
      $use = $false
      foreach($t in $tokens){ if($text -like ('*' + $t + '*')){ $use=$true; break } }
      if($use){ $keep.Add($text) }
      continue
    }
    $use2 = $false
    foreach($t in $tokens){ if($sel -like ('*' + $t + '*')){ $use2=$true; break } }
    if($use2){ $keep.Add($text) }
  }
  return ($keep -join "`r`n`r`n").Trim()
}

# Load used classes/ids from HTML
$html = Get-Content -Raw $HtmlPath
$classes = [regex]::Matches($html,'class\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | ForEach-Object { $_ -split '\s+' } | Where-Object { $_ } | Sort-Object -Unique
$ids = [regex]::Matches($html,'id\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

$families = @(
  '.ftco-', '.navbar', '.navbar-', '.nav-', '.btn', '.btn-', '.col-', '.row', '.container', '.container-fluid', '.icon-', '.bg-dark', '.text-center', '.ml-auto', '.d-flex', '.align-items-center', '.justify-content-center', '.g-'
)
$baseSelectors = @('html','body','h1','h2','h3','h4','h5','h6','p','a','img','label','button','input','select','textarea','pre','code','ul','ol','li','figure','figcaption','table','thead','tbody','tr','th','td','hr','small','strong','em','b','i','u','sub','sup','*','[data-aos]')

$cons = Build-CSS $CssPath $classes $ids $families $baseSelectors $false
$aggr = Build-CSS $CssPath $classes $ids @() $baseSelectors $true

$cons | Set-Content -Encoding UTF8 $ConservativeOut
$aggr | Set-Content -Encoding UTF8 $AggressiveOut

function Brace-Balance([string]$s){ ($s.ToCharArray() | Where-Object { $_ -eq '{' }).Count - ($s.ToCharArray() | Where-Object { $_ -eq '}' }).Count }
Write-Output ("Conservative: {0} (brace balance {1})" -f $ConservativeOut, (Brace-Balance $cons))
Write-Output ("Aggressive:   {0} (brace balance {1})" -f $AggressiveOut, (Brace-Balance $aggr))

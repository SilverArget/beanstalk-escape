Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$frameRoot = Join-Path $root 'assets/art/character_frames'
$sourceRoot = Join-Path $frameRoot 'source'

function Is-Skin([System.Drawing.Color]$c) {
    $cb = 128.0 - 0.168736 * $c.R - 0.331264 * $c.G + 0.5 * $c.B
    $cr = 128.0 + 0.5 * $c.R - 0.418688 * $c.G - 0.081312 * $c.B
    return $cb -ge 72 -and $cb -le 132 -and $cr -ge 132 -and $cr -le 184 -and $c.R -gt $c.G * 0.92
}

foreach ($skin in @('m1','m2','m3','f1','f2','f3')) {
    $sourcePath = Join-Path $sourceRoot "${skin}_front_imagegen_2026-10-13.png"
    $source = [System.Drawing.Bitmap]::new($sourcePath)
    $minX = $source.Width; $minY = $source.Height; $maxX = 0; $maxY = 0
    for ($y = 0; $y -lt $source.Height; $y += 2) { for ($x = 0; $x -lt $source.Width; $x += 2) {
        if ($source.GetPixel($x,$y).A -gt 12) { $minX=[Math]::Min($minX,$x); $minY=[Math]::Min($minY,$y); $maxX=[Math]::Max($maxX,$x); $maxY=[Math]::Max($maxY,$y) }
    }}
    $bounds = [System.Drawing.Rectangle]::new($minX,$minY,$maxX-$minX+1,$maxY-$minY+1)
    $scale = [Math]::Min(430.0/$bounds.Width, 476.0/$bounds.Height)
    $w = [int]($bounds.Width*$scale); $h = [int]($bounds.Height*$scale)
    $x0 = [int]((512-$w)/2); $y0 = [int]((512-$h)/2)
    $front = [System.Drawing.Bitmap]::new(512,512,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($front)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($source,[System.Drawing.Rectangle]::new($x0,$y0,$w,$h),$bounds,[System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose(); $source.Dispose()
    # Normalize mask geometry to the rendered opaque silhouette. Imagegen source
    # canvases may contain faint alpha outside the character, so the crop used to
    # draw the sprite is not a reliable anatomical coordinate system.
    $bodyMinX = 512; $bodyMinY = 512; $bodyMaxX = 0; $bodyMaxY = 0
    for ($y = 0; $y -lt 512; $y++) { for ($x = 0; $x -lt 512; $x++) {
        if ($front.GetPixel($x,$y).A -gt 64) {
            $bodyMinX=[Math]::Min($bodyMinX,$x); $bodyMinY=[Math]::Min($bodyMinY,$y)
            $bodyMaxX=[Math]::Max($bodyMaxX,$x); $bodyMaxY=[Math]::Max($bodyMaxY,$y)
        }
    }}
    $bodyW = [Math]::Max(1,$bodyMaxX-$bodyMinX+1); $bodyH = [Math]::Max(1,$bodyMaxY-$bodyMinY+1)
    $hair = [System.Drawing.Bitmap]::new(512,512,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $outfit = [System.Drawing.Bitmap]::new(512,512,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    for ($y=0; $y -lt 512; $y++) { for ($x=0; $x -lt 512; $x++) {
        $c=$front.GetPixel($x,$y); if ($c.A -le 16) { continue }
        $nx=($x-$bodyMinX)/[double]$bodyW; $ny=($y-$bodyMinY)/[double]$bodyH; $skinPixel=Is-Skin $c
        $brightness=0.299*$c.R + 0.587*$c.G + 0.114*$c.B
        $isFace=($nx -ge 0.32 -and $nx -le 0.68 -and $ny -ge 0.15 -and $ny -le 0.34)
        $isHair=($ny -lt 0.30 -and $brightness -ge 48 -and -not $skinPixel -and -not $isFace)
        $isTorso=($ny -ge 0.31 -and $ny -le 0.62 -and $nx -ge 0.16 -and $nx -le 0.84)
        $isLegs=($ny -gt 0.58 -and $ny -le 0.84 -and $nx -ge 0.25 -and $nx -le 0.75)
        if ($isHair) { $hair.SetPixel($x,$y,[System.Drawing.Color]::White) }
        if (($isTorso -or $isLegs) -and -not $skinPixel) { $outfit.SetPixel($x,$y,[System.Drawing.Color]::White) }
    }}
    $target = Join-Path $frameRoot $skin
    $front.Save((Join-Path $target 'front.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $hair.Save((Join-Path $target 'front_hair_mask.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $outfit.Save((Join-Path $target 'front_outfit_mask.png'),[System.Drawing.Imaging.ImageFormat]::Png)
    $front.Dispose(); $hair.Dispose(); $outfit.Dispose()
}

$sheet = [System.Drawing.Bitmap]::new((Join-Path $root 'assets/art/cosmetics/emblems_imagegen_2026-10-13.png'))
$names = @('emblem_leaf','emblem_star','emblem_sun','emblem_bolt','emblem_spider','emblem_crown')
for ($i=0; $i -lt 6; $i++) {
    $cell = [System.Drawing.Rectangle]::new(($i%3)*512,[Math]::Floor($i/3)*512,512,512)
    $icon = [System.Drawing.Bitmap]::new(256,256,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g=[System.Drawing.Graphics]::FromImage($icon); $g.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($sheet,[System.Drawing.Rectangle]::new(0,0,256,256),$cell,[System.Drawing.GraphicsUnit]::Pixel); $g.Dispose()
    $icon.Save((Join-Path $root "assets/art/cosmetics/$($names[$i]).png"),[System.Drawing.Imaging.ImageFormat]::Png); $icon.Dispose()
}
$sheet.Dispose()

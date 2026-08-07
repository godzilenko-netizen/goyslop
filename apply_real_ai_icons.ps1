[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Drawing

$art_dir = "C:\Users\ipala\.gemini\antigravity-ide\brain\e24f06bb-0fe0-4578-91c0-f7e28ba9d40b"
$dest_dir = "c:\Users\ipala\Desktop\игра\textures\skills"

if (-not (Test-Path -Path $dest_dir)) {
    New-Item -ItemType Directory -Path $dest_dir -Force
}

$items = @(
    @{
        src = [System.IO.Path]::Combine($art_dir, "bare_fist_d2_ultrapixel_1786053388737.png");
        dst = [System.IO.Path]::Combine($dest_dir, "fist_attack.png");
        x = 244; y = 236; w = 528; h = 528
    },
    @{
        src = [System.IO.Path]::Combine($art_dir, "fireball_d2_ultrapixel_1786053403580.png");
        dst = [System.IO.Path]::Combine($dest_dir, "fireball.png");
        x = 215; y = 215; w = 594; h = 594
    },
    @{
        src = [System.IO.Path]::Combine($art_dir, "ice_arrow_d2_ultrapixel_1786053418745.png");
        dst = [System.IO.Path]::Combine($dest_dir, "ice_arrow.png");
        x = 208; y = 208; w = 608; h = 608
    }
)

foreach ($item in $items) {
    if ([System.IO.File]::Exists($item.src)) {
        Write-Host "FOUND AI IMAGE: $($item.src)"
        $orig = [System.Drawing.Image]::FromFile($item.src)
        
        $cropRect = New-Object System.Drawing.Rectangle($item.x, $item.y, $item.w, $item.h)
        $croppedBmp = New-Object System.Drawing.Bitmap($item.w, $item.h)
        $g = [System.Drawing.Graphics]::FromImage($croppedBmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($orig, (New-Object System.Drawing.Rectangle(0, 0, $item.w, $item.h)), $cropRect, [System.Drawing.GraphicsUnit]::Pixel)
        
        $finalBmp = New-Object System.Drawing.Bitmap(128, 128)
        $gFinal = [System.Drawing.Graphics]::FromImage($finalBmp)
        $gFinal.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gFinal.DrawImage($croppedBmp, 0, 0, 128, 128)
        
        if ([System.IO.File]::Exists($item.dst)) {
            [System.IO.File]::Delete($item.dst)
        }
        
        $finalBmp.Save($item.dst, [System.Drawing.Imaging.ImageFormat]::Png)
        
        $gFinal.Dispose()
        $finalBmp.Dispose()
        $g.Dispose()
        $croppedBmp.Dispose()
        $orig.Dispose()
        
        Write-Host "SUCCESS: Applied AI icon to $($item.dst)"
    } else {
        Write-Host "ERROR: File missing: $($item.src)"
    }
}

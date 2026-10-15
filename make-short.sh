#!/bin/bash
# windOS Zen vertical short v3 (portrait-native): 12 shots x 2.4s = 28.8s, 1080x1920, 30fps
# ~100 BPM grid: cut every 2.4s (4 beats), caption stagger +0.9s inside each story block.
# v3 fixes the 9:16 aspect crime: NATIVE portrait wallpapers for full-bleed shots,
# cover-crop blurred fill (never stretch) for landscape screenshots, larger fg cards.
# STRETCH-GUARD: no bare scale=W:H without force_original_aspect_ratio may ever appear below.
set -e
W=/home/winmastt/windos-zen
OUT=$W/site/windos-zen-short.mp4
TMP=/tmp/opencode/wzshort3
FB=/home/winmastt/.local/share/fonts/Microsoft/TrueType/SegoeUI/segoeuib.ttf
FSB=/home/winmastt/.local/share/fonts/Microsoft/TrueType/SegoeUI/seguisb.ttf
FR=/home/winmastt/.local/share/fonts/Microsoft/TrueType/SegoeUI/segoeui.ttf
MES=$W/site/music/uplifting-bass-lily-j.mp3
MESS=20
mkdir -p $TMP
cd $W

# ---- stretch-guard: portrait masters must exist; rule: never scale=X:Y without ----
# ---- force_original_aspect_ratio (cover/crop or aspect-preserved only) ----
for p in assets/generated/wallpaper/windos-zen-1080x1920.png assets/generated/wallpaper/windos-zen-classic-1080x1920.png; do
  [ -f "$W/$p" ] || { echo "STRETCH-GUARD FAIL: missing $p"; exit 1; }
done

# ---- self-captured shots ONLY (shot on 2026-10-14 from live-build ISO in QEMU;
# ---- owner directive: no /home/winmastt/wz-f12*.png, no site/ad-zen.png) ----
for p in assets/shots-self/shot-desk-welcome.png assets/shots-self/shot-desk.png assets/shots-self/shot-files.png assets/shots-self/shot-inst-welcome.png assets/shots-self/shot-inst-edition.png assets/shots-self/shot-kernel.png assets/shots-self/shot-bootmenu.png; do
  [ -f "$W/$p" ] || { echo "SELF-SHOT FAIL: missing $p"; exit 1; }
done

# ---- copy (c2a/c3a softened 2026-10-14: settled-idle measurement on live ISO
# ---- showed 184 procs / ~1.0Gi used — numbers unearned, so option (b):
# ---- no numeric proof shots, qualitative copy only. c4/c5 kept: verified
# ---- 6 editions in Calamares, liquorix kernel + zram0 live in the VM.) ----
printf 'Your 2009 laptop called.' > $TMP/c1a.txt
printf 'It wants back in the game.' > $TMP/c1b.txt
printf 'Bloat did not make the cut.' > $TMP/c2a.txt
printf 'Light by design.' > $TMP/c2b.txt
printf 'Small footprint.' > $TMP/c3a.txt
printf 'Room to breathe.' > $TMP/c3b.txt
printf '6 desktops. One installer.' > $TMP/c4a.txt
printf 'Pick yours in Calamares.' > $TMP/c4b.txt
printf 'zRAM every boot.' > $TMP/c5a.txt
printf 'Liquorix Zen kernel inside.' > $TMP/c5b.txt
printf 'windOS Zen 1.0 Breeze' > $TMP/c6a.txt
printf 'winmasttdev.github.io/windos' > $TMP/c6b.txt
printf 'L I G H T E R   T H A N   A I R' > $TMP/kick.txt

FRAMES=72   # 2.4s @30fps
N1=$((FRAMES-1))

# $1 = move name -> prints zoompan x/y/z exprs (operate on 2160-wide upscale, out 1080x1920)
# ALL moves eased (ease-out quad/cubic or sinusoidal) — no linear on/$N1 ramps.
move() {
  case $1 in
    push)     echo "z='1.00+0.10*(1-pow(1-on/$N1\,2))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'" ;;
    driftR)   echo "z=1.12:x='(iw-iw/zoom)*(1-pow(1-on/$N1\,2))':y='ih/2-(ih/zoom/2)'" ;;
    hold)     echo "z=1.05:x='iw/2-(iw/zoom/2)+6*sin(2*PI*on/36)':y='ih/2-(ih/zoom/2)+4*cos(2*PI*on/48)'" ;;
    driftL)   echo "z=1.12:x='(iw-iw/zoom)*pow(1-on/$N1\,1.7)':y='ih/2-(ih/zoom/2)'" ;;
    whipR)    echo "z=1.12:x='(iw-iw/zoom)*(1-pow(1-on/$N1\,2.5))':y='ih/2-(ih/zoom/2)'" ;;
    pullback) echo "z='1.12-0.10*(1-pow(1-on/$N1\,1.8))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'" ;;
    pushslow) echo "z='1.00+0.06*(1-pow(1-on/$N1\,2))':x='iw/2-(iw/zoom/2)':y='(ih-ih/zoom)*(1-(1-pow(1-on/$N1\,2))*0.5)'" ;;
    whipL)    echo "z=1.12:x='(iw-iw/zoom)*pow(1-on/$N1\,2.5)':y='ih/2-(ih/zoom/2)'" ;;
    hold2)    echo "z=1.06:x='iw/2-(iw/zoom/2)+5*cos(2*PI*on/30)':y='ih/2-(ih/zoom/2)+5*sin(2*PI*on/44)'" ;;
    driftR2)  echo "z=1.08:x='(iw-iw/zoom)*(1-pow(1-on/$N1\,2))':y='(ih-ih/zoom)*(1-pow(1-on/$N1\,2))'" ;;
    push2)    echo "z='1.02+0.09*(1-pow(1-on/$N1\,2))':x='iw/2-(iw/zoom/2)':y='(ih-ih/zoom)*(0.5-0.18*(1-pow(1-on/$N1\,2)))'" ;;
    holdend)  echo "z=1.04:x='iw/2-(iw/zoom/2)+3*sin(2*PI*on/52)':y='ih/2-(ih/zoom/2)+3*cos(2*PI*on/60)'" ;;
  esac
}

# caption alpha/rise (fade+rise, no typewriter). $1=start time
capA="fontfile=$FB:textfile=TA:fontsize=58:fontcolor=white:box=1:boxcolor=black@0.72:boxborderw=20:x=(w-text_w)/2:y='h-640-36*(1-min(1\,t/0.35))':alpha='min(1\,t/0.35)'"
capB="fontfile=$FSB:textfile=TB:fontsize=46:fontcolor=#38bdf8:box=1:boxcolor=black@0.72:boxborderw=18:x=(w-text_w)/2:y='h-500-36*(1-min(1\,max(0\,(t-0.9))/0.35))':alpha='if(lt(t\,0.9)\,0\,min(1\,(t-0.9)/0.35))'"
capAhold="fontfile=$FB:textfile=TA:fontsize=58:fontcolor=white:box=1:boxcolor=black@0.72:boxborderw=20:x=(w-text_w)/2:y=h-640"
capBhold="fontfile=$FSB:textfile=TB:fontsize=46:fontcolor=#38bdf8:box=1:boxcolor=black@0.72:boxborderw=18:x=(w-text_w)/2:y=h-500"
kick="fontfile=$FR:textfile=$TMP/kick.txt:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=14:x=(w-text_w)/2:y=150:alpha='min(1\,t/0.25)'"
FILM="noise=alls=5:allf=t,vignette=angle=PI/5,eq=contrast=1.04:saturation=1.15:brightness=0.0,drawbox=x=0:y=ih*0.55:w=iw:h=ih*0.45:color=black@0.35:t=fill"
FILMFULL="noise=alls=5:allf=t,eq=gamma=1.55:brightness=0.045:saturation=1.12,vignette=angle=PI/5,eq=contrast=1.03:brightness=0.0,drawbox=x=0:y=ih*0.55:w=iw:h=ih*0.45:color=black@0.35:t=fill"
FILMEND="noise=alls=5:allf=t,eq=gamma=1.5:brightness=0.04:saturation=1.12,vignette=angle=PI/5,drawbox=x=0:y=0:w=iw:h=ih:color=black@0.28:t=fill"

# $1=seg $2=img $3=mode $4=move $5=capAfile $6=capBfile $7=capmode(live|hold) [$8=endcard]
mkseg() {
  local n=$1 img=$2 mode=$3 mv=$4 ta=$5 tb=$6 cm=$7 end=$8
  local Z=$(move $mv)
  local A B K
  if [ "$cm" = live ]; then A=${capA/TA/$ta}; B=${capB/TB/$tb};
  else A=${capAhold/TA/$ta}; B=${capBhold/TB/$tb}; fi
  if [ "$end" = end ]; then
    # end card: titles sit BELOW the baked wordmark (classic portrait has cloud
    # ~40% + wordmark ~55%), so park them at h/2+180/+300 over dark grid.
    A="fontfile=$FB:textfile=$ta:fontsize=72:fontcolor=white:box=1:boxcolor=black@0.72:boxborderw=24:x=(w-text_w)/2:y='h/2+180-30*(1-min(1\,t/0.35))':alpha='min(1\,t/0.35)'"
    [ "$cm" = hold ] && A="fontfile=$FB:textfile=$ta:fontsize=72:fontcolor=white:box=1:boxcolor=black@0.72:boxborderw=24:x=(w-text_w)/2:y=h/2+180"
    B="fontfile=$FSB:textfile=$tb:fontsize=44:fontcolor=#38bdf8:box=1:boxcolor=black@0.72:boxborderw=18:x=(w-text_w)/2:y=h/2+300"
    K=""
  else K=",drawtext=$kick"; fi
  if [ "$mode" = fg ]; then
    ffmpeg -y -v error -i "$img" -loop 1 -framerate 30 -i "$img" -filter_complex \
      "[0:v]scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,scale=2160:-2,zoompan=$Z:d=$FRAMES:s=1080x1920:fps=30,gblur=sigma=30,eq=brightness=0.03:saturation=1.25,drawbox=x=0:y=0:w=iw:h=ih:color=black@0.32:t=fill[bg];[1:v]scale=1040:-2[fg];[bg][fg]overlay=x=(W-w)/2:y='min(600\,1220-h)'[base];[base]$FILM,drawtext=$A,drawtext=$B$K[v]" \
      -map "[v]" -frames:v $FRAMES -r 30 -c:v libx264 -preset veryfast -pix_fmt yuv420p $TMP/seg$n.mp4
  else
    local GRADE=$FILMFULL
    [ "$end" = end ] && GRADE=$FILMEND
    ffmpeg -y -v error -i "$img" -filter_complex \
      "[0:v]scale=2160:-2,zoompan=$Z:d=$FRAMES:s=1080x1920:fps=30[base];[base]$GRADE,drawtext=$A,drawtext=$B$K[v]" \
      -map "[v]" -frames:v $FRAMES -r 30 -c:v libx264 -preset veryfast -pix_fmt yuv420p $TMP/seg$n.mp4
  fi
  echo "seg$n ($mv/$cm) done: $(du -h $TMP/seg$n.mp4 | cut -f1)"
}

WP=$W/assets/generated/wallpaper/windos-zen-1080x1920.png
WPC=$W/assets/generated/wallpaper/windos-zen-classic-1080x1920.png
SH=$W/assets/shots-self
mkseg 1  "$WP"                  full push     $TMP/c1a.txt $TMP/c1b.txt live
mkseg 2  "$WP"                  full driftR   $TMP/c1a.txt $TMP/c1b.txt hold
mkseg 3  $SH/shot-desk-welcome.png fg hold    $TMP/c2a.txt $TMP/c2b.txt live
mkseg 4  $SH/shot-desk.png         fg driftL  $TMP/c2a.txt $TMP/c2b.txt hold
mkseg 5  $SH/shot-files.png        fg whipR   $TMP/c3a.txt $TMP/c3b.txt live
mkseg 6  $SH/shot-term.png         fg pullback $TMP/c3a.txt $TMP/c3b.txt hold
mkseg 7  $SH/shot-inst-welcome.png fg pushslow $TMP/c4a.txt $TMP/c4b.txt live
mkseg 8  $SH/shot-inst-edition.png fg whipL   $TMP/c4a.txt $TMP/c4b.txt hold
mkseg 9  $SH/shot-kernel.png       fg hold2   $TMP/c5a.txt $TMP/c5b.txt live
mkseg 10 $SH/shot-bootmenu.png     fg driftR2 $TMP/c5a.txt $TMP/c5b.txt hold
mkseg 11 "$WPC"                 full push2    $TMP/c6a.txt $TMP/c6b.txt live end
mkseg 12 "$WPC"                 full holdend  $TMP/c6a.txt $TMP/c6b.txt hold end

printf "file '$TMP/seg%02d.mp4'\n" 1 2 3 4 5 6 7 8 9 10 11 12 > /dev/null
(for i in 1 2 3 4 5 6 7 8 9 10 11 12; do echo "file '$TMP/seg$i.mp4'"; done) > $TMP/list.txt
ffmpeg -y -v error -f concat -safe 0 -i $TMP/list.txt -c copy $TMP/vonly.mp4

# music: Mixkit royalty-free bed (Lily J "Uplifting Bass", free license, CREDIT.txt
# beside it — safe for TikTok/YouTube, no Content ID). Slice skips the quiet
# intro, rides the full groove; -14dB bed with 1s fades under 28.8s.
ffmpeg -y -v error -ss $MESS -t 28.8 -i "$MES" -filter_complex \
  "[0:a]aformat=sample_rates=44100:channel_layouts=stereo,volume=0.2,afade=t=in:st=0:d=1,afade=t=out:st=27.8:d=1[a]" \
  -map "[a]" -c:a aac -b:a 128k -ar 44100 $TMP/bed.m4a
ffmpeg -y -v error -i $TMP/vonly.mp4 -i $TMP/bed.m4a -map 0:v -map 1:a -c:v copy -c:a copy -movflags +faststart -shortest $OUT
echo "FINAL: $(du -h $OUT | cut -f1)"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,codec_name,pix_fmt -show_entries format=duration -of default=noprint_wrappers=1 $OUT
ffprobe -v error -select_streams a:0 -show_entries stream=codec_name,sample_rate,bit_rate -of default=noprint_wrappers=1 $OUT
ffmpeg -y -v error -ss 27 -i $OUT -frames:v 1 $W/site/windos-zen-short-poster.png
for t in 1 8 17 27; do ffmpeg -y -v error -ss $t -i $OUT -frames:v 1 $TMP/check$t.png; done
ls -lh $OUT $W/site/windos-zen-short-poster.png $TMP/check*.png
ffmpeg -i $OUT -af volumedetect -vn -f null /dev/null 2>&1 | grep -E "mean_volume|max_volume"

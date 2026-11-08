# The mutations of Wolly.Jpeg, progressive JPEG and EXIF orientation,
# sourced by scripts/mutate.sh and scripts/mutate-target.sh.
mutations+=(
	"Jpeg.hiq|s/                        if marker = 194 then/                        if false then/|a progressive frame read as sequential"
	"Jpeg.hiq|s/            putCoefficient(\&~store, at, dc \* weight(low));/            putCoefficient(\&~store, at, dc);/|the first DC scan not shifted by its low bit"
	"Jpeg.hiq|s/                putCoefficient(\&~store, at, old + weight(low));/                skip;/|a DC refinement bit dropped"
	"Jpeg.hiq|s/                    bits->run := blocks - 1;/                    bits->run := blocks;/|an end-of-band run one block too long"
	"Jpeg.hiq|s/extend(receive(data, \&~bits, bitCount), bitCount) \* weight(low));/extend(receive(data, \&~bits, bitCount), bitCount));/|a first AC scan not shifted by its low bit"
	"Jpeg.hiq|s/                putCoefficient(\&~store, index, v - weight(low));/                putCoefficient(\&~store, index, v + weight(low));/|a negative coefficient refined towards 0"
	"Jpeg.hiq|s/                        value := zero - weight(low);/                        value := weight(low);/|a new coefficient of a refinement always positive"
	"Jpeg.hiq|s/                        bits->run := blocks;/                        bits->run := blocks - 1;/|the end-of-band run of a refinement one block short"
	"Jpeg.hiq|s/                            if run = 0 then/                            if run = 1 then/|the new coefficient of a refinement one zero late"
	"Jpeg.hiq|s/            unitsAcross := nth(frame, onlyBase + 9);/            unitsAcross := nth(frame, onlyBase + 7);/|a scan of one component over whole units, not the blocks of the picture"
	"Jpeg.hiq|s/                    sy := (height - 1) - ox;/                    sy := ox;/|orientation 6 turned the wrong way"
	"Jpeg.hiq|s/            if turn >= 5 then/            if turn >= 6 then/|orientation 5 keeps width and height"
	"Jpeg.hiq|s/        if tiffWord(data, tiff + 2, little) \/= 42 then/        if tiffWord(data, tiff + 2, little) = 42 then/|EXIF with its magic 42 refused"
	"Jpeg.hiq|s/            if (tiffWord(data, entry, little) = 274) and/            if (tiffWord(data, entry, little) = 275) and/|another tag read as the orientation"
)

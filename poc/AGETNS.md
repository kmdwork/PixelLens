技術検証(PoC)

目的:
JPEG保存時に
TIFF / EXIF系解像度情報を更新可能か確認する

JFIFは表示対象として読込可能か確認する

検証方式:
Swift + ImageIO を使用して
CGImageSource / CGImageDestination により
JPEGメタデータの読込と保存を検証する

確認項目:

1.
JPEG読込

2.
JFIFのXDensity/YDensity/DensityUnit取得

3.
TIFF / EXIF系のXResolution/YResolution/ResolutionUnit取得

4.
300dpiへ変更

5.
保存

6.
再読込

7.
TIFF / EXIF系が300dpiになっていること

8.
撮影日時など
その他のEXIFが保持されること

9.
保存後のJPEGが正常に再読込できること

10.
Preview等の一般的なmacOSアプリで
正常に開けること

11.
JFIFの値が保持または別値として観測できること

合格条件:

- EXIF更新成功
- TIFF / EXIF系のunitが期待通りであること
- 他EXIF保持成功
- 保存後もJPEGとして正常に読めること
- JFIFが表示用情報として読めること

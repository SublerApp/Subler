# Subler News

## Subler 1.9.1

- Fixed the queue AppleScript dictionary
- Added a work around for a macOS 26 issue that could cause a crash when editing the file name and metadata token fields in the preferences


## Subler 1.9.0

- Updated UI for macOS 26
- Preserves extended language tags from Matroska files
- Fixed the services ids in the metadata map


## Subler 1.8.9

- Expanded the AppleScript dictionary [Mock1]
- Added additional keyboard shortcuts [Mock1]
- Added support for unofficial metadata often used for Audiobooks
- Make it possible to use the services ids in the metadata map
- Fixed the "Insert a chaper at the beginning" menu item action
- Fixed Swedish Ratings
- Fixed the "None" artwork option in the Queue


## Subler 1.8.8

- Fixed a crash that happened when editing a preset


## Subler 1.8.7

- Preserves additional metadata from Matroska
- Fixed a regression that made the "Send to queue" and "Queue" toolbar button unclickable


## Subler 1.8.6

- Added a "Check only selected track" contextual menu item in the importer sheet [karstenBriksoft]
- Added ability to set imported multichannel AAC track to Passthru + AAC [sxflynn]
- Added IPT-C2 and Undefined color profiles
- Improved the artworks views to make them remember the zoom level
- Improved the behaviour of a cancelled save operation to avoid running an optimize pass
- Fixed the issue where Apple TV metadata isn't returned for TV/Movies that Apple doesn't currently sell in the given region [Mock1]


## Subler 1.8.5

- Improved keyboard navigation in the document window
- Fixed FLAC audio decoding


## Subler 1.8.4

- Fixed metadata copy & paste


## Subler 1.8.3

- Reworked windows toolbars
- Improved AppleTV provider artworks matching to avoid showing unrelated artworks
- Fixed a regression that broke ALAC muxing


## Subler 1.8.2

- Improved save performance


## Subler 1.8.1

* Fixed 64bit files creation
* Fixed reading some MP4 file
* Added "Original Content" and "Enhances speech intelligibility" media characteristics
* Added "Compilation" metadata


## Subler 1.8

* Preliminary VVC support
* Added a queue action to set the preferred enabled track in an alternate group
* Added Spanish (Latin America) localization
* Preserve ambient viewing environment metadata at the container level
* Preserve Dolby Vision AV1 metadata

* Requires macOS 10.13 or later


## Subler 1.7.4 / 1.7.5

* Fixed an issue that prevented the AppleTV metadata provider from working.


## Subler 1.7.3

* Fixed an issue that prevented importing some Dolby Vision tracks.
* Added French localizations.


## Subler 1.7.2

* Fixed an issue that could cause a crash when trying to import MOV files.
* Update localizations.


## Subler 1.7.1

* Resolved a crash when trying to load invalid OCR trained data files.
* Resolved an issue that prevented the download of valid OCR trained data files in the preferences panel.


## Subler 1.7

* Improved Dolby Vision support.
* Updated Tesseract OCR library.


## Subler 1.6.12

* Preserve HDR10 metadata at the container level.


## Subler 1.6.11

* Fixed an issue in the Matroska importer that could cause wrong tracks durations.
* Added HLG and more colorspaces to the video property view.


## Subler 1.6.10

* New app icon.
* Added a keyboard shortcut to the "Import File…" menu item.


## Subler 1.6.9

* Fixes TheTVDB search when the TV Show title contains a "*" .


## Subler 1.6.8

* Improves AppleTV TV Shows seasons matching.
* Fixes an issue that prevented setting the 9-16-9 color tag.


## Subler 1.6.7

* Improves AppleTV TV Shows seasons matching.
* Fixes a regression that prevented Atmos tracks from being properly signaled.
* Adds Chinese localization.


## Subler 1.6.6

* Universal App. Subler will run natively on Apple Silicon.
* Improves TheTVDB TV Shows search.
* Fixes an hang that could happen when importing mkv files.


## Subler 1.6.5

* Fixes Apple TV metadata search.


## Subler 1.6.4

* Fixes an issue that prevented uncheking tracks in the import sheet.
* Fixes an issue that prevented the parsing of some metadata.
* Improves Srt export. Subtitles tracks with edit lists are properly exported.
* Improved VobSub OCR subtitles timing.


## Subler 1.6.2

* Adds Irish iTunes Store ratings.


## Subler 1.6.1

* Episode images will be now correctly retrieved from TheMovieDB.


## Subler 1.6

* Improves keyboard navigation in the document window, left and right arrow keys can now switch to the left/right tabs.
* Improves selection of the cover art of a specific size in the queue (standard, square, rectangle/16-9).


## Subler 1.5.22

* "4k" is not set automatically anymore because the AppleTV won't stream mp4 with such metadata.
* Fixes an issue that could led to a crash when importing a 5.1 channels ac3 file on macOS 10.15.
* Fixes Indian iTunes Store.


## Subler 1.5.21

* Adds a "4k" option to the "HD Video" metadata item.
* Fixes an issue in queue artwork type selection.


## Subler 1.5.20

* Fixes a crash when importing a .ac3 file on 10.15.
* Fixes an issue with "Release Date" time zone.


## Subler 1.5.19

* Renames "Send to iTunes" to "Send to TV" on macOS 10.15, and fixes it to actually add the movie to the TV app.


## Subler 1.5.18

* Preserves the split view size if "Remember window size" option is enabled.
* Adds a "none" option to not download artworks in the Queue.


## Subler 1.5.17

* Improves the reliability of Squared TV Artworks.
* Improves the iTunes Store TV Show results.


## Subler 1.5.16

* Upgrades the OCR engine to Tesseract 4. Language data files to improve the results quality can be download directly from Subler OCR preferences panel.
* Fixes importing AAC audio tracks from some malformed MOV files.


## Subler 1.5.15 ##

* Switch to Plex mirror of ChapterDB.


## Subler 1.5.14 ##

* Fixes "studio" and "copyright" info not being found when searching metadata on the iTunes Store.
* Adds an option to auto-rename all audio tracks according to their number of channels. Thanks to Sidney S.


## Subler 1.5.13 ##

* Actually fixes an issue when manually insert a track number.


## Subler 1.5.12 ##

* Fixes an issue when manually insert a track number.
* Improves MOV imports.
* Fixes a hang when requesting metadata from TheMovieDB.


## Subler 1.5.10 ##
 
* Fixes queue autostart option.
* Fixes AppleScript support.


## Subler 1.5.9 ##

* Fixed an issue that might result in a delay when importing a EAC3+Atmos track from a MKV file.
* Improved the "Send to iTunes" option to avoid iTunes automatically playing a file.


## Subler 1.5.8 ##

* Fixes ChapterDB.
* Fixes metadata provider languages in the queue options.
* Improves EAC3+Atmos parser.


## Subler 1.5.7 ##

* Fixes Norway iTunes Store.
* Improves iTunes Store tv show season numbers.


## Subler 1.5.6 ##

* Fixes iTunes Store metadata provider after Apple's latest api changes.


## Subler 1.5.5 ##

* Improved tv show results from iTunes Store.


## Subler 1.5.4 ##

* Fixes another issue in the iTunes Store provider.
* Improves tv show searches when using romanized Japanese.


## Subler 1.5.3 ##

* Fixes an issue in the iTunes Store provider.


## Subler 1.5.1 ##

* Fixes an issue that could lead to a crash when remuxing certain EAC3 tracks.


## Subler 1.5 ##

* Fixes an issue with iTunes Store provider.
* Displays all the result from TheMovieDB (before only the first 20 were shown).
* The "load external subtitles" queue action now works properly if the subtitles file name has not a language in it.
* Recognises Atmos in EAC3 and properly muxes it from MKV.


## Subler 1.4.12 (2018-06-28)

* Fixes an issue with TheMovieDB.
* Partial support for dark mode on macOS 10.14.


## Subler 1.4.11 (2018-06-07)

* Fixes TheTVDB poster thumbnail not loading properly.
* Various bug fixes.


## Subler 1.4.10 (2018-04-13)

* Added a "Send to iTunes" queue action.
* The Queue now remembers the recent selected destinations.


## Subler 1.4.9 (2018-03-15)

* Added formatting options to filename and metadata placeholders (text case, leading zero for numbers, etc…).


## Subler 1.4.8 (2018-03-02)

* Added Argentina and Taiwan iTunes Store.
* Added a queue action to remove the existing metadata.
* Fixed the "Load external subtitles" queue action.
* Fixed a rare crash that could happens when searching for tv show metadata on iTunes Store.


## Subler 1.4.7.1 (2018-03-06, 10.9 bugfix version)

* Fixed the "Load external subtitles" queue action.
* Fixed a rare crash that could happens when searching for tv show metadata on iTunes Store.


## Subler 1.4.7 (2018-02-03)

* Improved subtitles compatibility with VLC 3.


## Subler 1.4.6 (2017-12-11)

* Added an option to format the filename.


## Subler 1.4.5 (2017-11-29)

* Fixed an issue with Sub Station Alpha files with Windows end-of-line.
* Show Squared TV artworks when searching with TheMovieDB too.


## Subler 1.4.4 (2017-11-21)

* Allow partial tv series name match when searching on the iTunes Store.
* Fixed a bunch of regression caused by rewriting parts of Subler in Swift.


## Subler 1.4.3 (2017-11-4)

* Fixed a bunch of regression caused by rewriting parts of Subler in Swift.


## Subler 1.4.2 (2017-10-27)

* Fixed an issue that could cause some samples to be dropped when importing a file with the audio "AAC + Pasthru" mixdown selected.
* Improved support for reading PCM stored in Matroska.


## Subler 1.4.1 (2017-10-18)

* Fixed yet another crash that could happen on older macOS versions when searching for chapters.


## Subler 1.4 (2017-10-4)

* Fixed a crash when using the "Search chapters" function.
* Fixed metadata search when the search term contains ",".
* Added support for Advanced SubStation Alpha files (.ssa and .ass).


## Subler 1.3.8 (2017-9-28)

* Restored 10.9 compatibility.
* Fixed a crash when importing some mov files.
* Fixed the subtitles "forced" option, it was not saved propertly in some cases.


## Subler 1.3.7 (2017-9-19)

* Preserve tracks video rotation.
* Improved search for some tv shows on iTunes Store.
* Added an option to force Subler to use the 'hvc1' fourCC for HEVC, this might or might not allow your file to be played in QuickTime or High Sierra, a better solution will come in a future update.


## Subler 1.3.6 (2017-8-30)

* Fixed an issue that could cause TheTVDB to return data for the wrong series.
* Added an option to decide if existing artworks and annotations can be kept or not when a preset is applied.


## Subler 1.3.5 (2017-8-10)

* Retrieve square TV Show artworks from http://squaredtvart.tumblr.com .


## Subler 1.3.4 (2017-8-3)

* Show only the related season poster images from TVDB in the artwork selection window.


## Subler 1.3.3 (2017-7-5)

* Subler can now retrieve TV Shows metadata from TheMovieDB.
* Various bug fixes.


## Subler 1.3.2 (2017-6-10)

* Fixed an issue that could prevent the retrieval of TheTVDB series posters.


## Subler 1.3.1 (2017-5-29)

* Uses TheTVDB new API, the previous version is being retired (old version of Subler won't be able to fetch metadata from TheTVDB after October 1st, 2017).


## Subler 1.3 (2017-5-22)

* Support for DTS to AC3 + AAC conversion.
* Configurable chapter preview position.
* Fixed a crash then could happen when reading a file tagged with another app.


## Subler 1.2.9 (2017-4-20)

* Improve iTunes Store TV Show result.
* Fixed an issue that could result is out of sync subtitles when OCRing a PGS track.


## Subler 1.2.8

* Fixed an issue that prevented opening files with AppleScript.


## Subler 1.2.7 (2017-3-24)

* Fixed an issue that prevented opening files with AppleScript.


## Subler 1.2.6 (2017-3-13)

* Better TV Show results for iTunes Store.
* Reverted TheTVDB to http to an avoid issue.


## Subler 1.2.5 (2017-1-25)

* Fixed a crash when reading metadata from a mov file.
* Added a queue action to set a file color space.


## Subler 1.2.3 (2016-12-9)

* Fixed a crash that could happen when reading a set saved in a previous version.
* Keep the chapters track language after an edit.
* PlaylistID metadata is now properly written to the file.
* Added an option in the queue to select the preferred artwork (iTunes, episode, season) to use when getting metadata from TheMovieDB or TheTVDB.


## Subler 1.2.2 (2016-11-30)

* Added support for extended language tag. The extended language tag can provide better language information, including information such as region, script, variation, and so on.
* Added support for setting the color tag of a video track.


## Subler 1.2.1 (2016-11-19)

* Fixed a localization issue ("Artist" metadata item was shown as "Album").
* Various bug fixes.


## Subler 1.2 (2016-11-16)

* Added Italian localization
* Removed the "Other settings" metadata tab. Those metadata can now be added/removed the same way as the other metadata
* Added Philippines and Hong Kong ratings/iTunes Store
* Fixed frame rate selection for raw h.264
* Fixed a crash when opening some audiobooks


## Subler 1.1.8

* Fixed an issue that prevented the audio fallback from begin set


## Subler 1.1.7 (2016-9-23) ##

* PCM audio can be converted to AAC.
* Added a DRC option in the advanced preferences.


## Subler 1.1.5 (2016-9-12) ##

* Matroska files with more than 32 tracks can now be properly imported.


## Subler 1.1.4 ##

* Audio tracks with a sample rate higher than 48000 kHz can now be correctly converted to AAC.


## Subler 1.1.3 (2016-8-19) ##

* Sometime the rating was not saved properly, fixed.
* Fixed decoding of E-AC3 audio.


## Subler 1.1.2 (2016-8-16) ##

* HEVC (H.265) is now supported.
* Notification when the queue is completed.


## Subler 1.1.1 (2016-8-9) ##

* Fixed a couple of regression in the iTunes Store metadata importer.


## Subler 1.1 (2016-8-5) ##

* More robust audio conversion.
* User configurable metadata import, the way Subler maps data from iTunes Store, TheMovieDB and TheTVDB can be manually configured if you don't like Subler defaults.
* Better placement for the media characteristics options.
* 64bit.
* Requires OS X 10.9 or later.


## Subler 1.0.9 (2016-2-16) ##

* Updated Sparkle.
* Fixed a regression in the srt parser that broke the font tag.
* Added EAC3 support.


## Subler 1.0.8 ##

* Fixed a crash on 10.10 and earlier.


## Subler 1.0.7 (2016-1-8) ##

* ChapterDb support. Search in ChapterDB database from File -> Import -> Search Chapters Online… or add the toolbar item by customizing the toolbar. Result quality may vary.
* Fixed MPEG-4 Visual tracks muxing from mp4.
* Added an option to automatically add the missing audio fallback tag to ac-3 tracks.


## Subler 1.0.6 ##

* Resolved a crash that could happen when downloading some artworks from iTunes Store.


## Subler 1.0.5 (2015-11-0) ##

* Resolved an issue that prevented the download of high resolution artworks from iTunes Store.


## Subler 1.0.4 (2015-10-16) ##

* Fixed ac3 to aac downmix on 10.11.


## Subler 1.0.2 (2015-09-23) ##

* Fixed a crash that could happen when trying to open a srt file on 10.9 or earlier.
* Media characteristics tags are now supported. You can use this feature to tag for example a SDH subtitles track or an auxiliary track. QuickTime will use this settings to append a “SDH” label in the tracks selection menu or let you select two different tracks with the same language. See the QuickTime File Format specification for more info. You can edit these kind of tags from Edit -> Media Characteristics Tags menu.


## Subler 1.0.1 (2015-09-03) ##

* Fixed a regression in 1.0 that broke the mov importer.


## Subler 1.0 ##

* This release requires OS X 10.7 or later.
* Added ability to update chapter track titles from Handbrake-compatible chapters CSV file.
* Added a shortcut to the "Send to Queue" menu, cmd-b.
* Added a "Open in Queue" menu item.
* Fixed the size of the artworks from iTunes Store.
* Added Mexican iTunes Store.
* Fixed a good number of bugs.


## Subler 0.31 (2014-12-15) ##

* Added the Russian iTunes Store.
* Fixed previews track generation.
* Fixed a rare crash when importing a .srt file.
* Fixed an issue where a subtitles track bold style couldn't be exported properly to srt.
* Fixed an hang when trying to mux an unsupported track.


## Subler 0.30 ##

* Fixed another crash with ratings.


## Subler 0.29 ##

* Fixed a crash that could happen opening a file with ac3 audio if it was Subler first run.
* Fixed the rename all chapters function.


## Subler 0.28 ##

* Fixed a crash that could happen when editing a mp4 with an unknown rating tag.


## Subler 0.27 ##

 * Improved queue.
 * Improved metadata search for non English languages.
 * Added the "Alert Tone" media type and the "m4r" file type.
 * Added a way to rename all the chapters in the format “Chapter <num>”.
 * The audio codecs (ac-3, vorbis, flac, dts) are now bundled with Subler.
 * Alert when the save destination folder is read-only.
 * Improved validation in the optimize feature.
 

## Subler 0.25 ##

 * Fixed a cache invalidation issue that could prevent the download of updated movie and tv show metadata.
 * Fixed mono audio conversion.
 * Various bug fixed.
 

## Subler 0.24 ##

 * New audio conversion option: AAC + AC-3.
 * Better results from TVDB and iTunes Store.
 

## Subler 0.23 ##

 * Fixed a crash that could occur when searching for metadata with TheMovieDB.
 * Retrieve TV Network, Genre and Rating from TheTVDB.
 * Better posters selection with TheMovieDB.
 

## Subler 0.21-0.22 ##
 
 * Fixed a crash that could occur when searching for metadata.
 * Fixed a crash that could occur when adding chapters from a txt file.
 * Various bug fixed.
 

## Subler 0.20 ##
 
 * Updated TheMovieDB api.
 * Added iTunes Store metadata importer.
 * Improved ratings selection.
 * Srt -> tx3g conversion improvement: font color, subtitles position (bottom, top), forced subtitles. (refer to the SrtFileFormat wiki page for an example).
 * Various bug fixed.
 

## Subler 0.19 ##

 * HDMV / PGS OCR.
 * Fixed an issue that caused the save operation to take a long time. 
 * Added "Home Video" to the media kind list.
 

## Subler 0.18 ##

 * Fixed an issue with thetvdb, results were not returned for some tv series. 
 * Fixed some regression in the mov importer.
 * Added "iTunes U" to the media kind list.
 

## Subler 0.17 ##

 * Forced subtitles tracks. A new option to set a track as "forced". iDevices will automatically display the right forced track for a given language (does not work with vobsub, only tx3g) 
 * Ocr languages. Subler will now check ~/Library/Application Support/Subler/tessdata for Tesseract traineddata files.
 * Fixed an issue with the rating tag.
 

## Subler 0.16 ##

 * VobSub OCR to text for subtitles
 * Per track conversion settings.
 * ALAC and DTS muxing support.
 * Queue window for batch operations.
 * 1080p tag (iTunes 10.6).

 * 0.16 requires Mac OS X 10.6 or higher.
 

## Subler 0.14 ##

 * TMDb and TVDB metadata search engine (replacing tagChimp)
 * Metadata Sets. Metadata Sets can now be saved an quickly reloaded from the Metadata View.
 * Added support for Non-Drop Frame timecode in SCC files.
 * Added an "Export" menu item to export tx3g back to srt and chapters to txt
 * Added Podcast related tags
 * Various bug fixes


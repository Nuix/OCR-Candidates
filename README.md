OCR-Candidates
=============

![This script was last tested in Nuix 8.8](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-8.8-green.svg)

View the GitHub project [here](https://github.com/Nuix/OCR-Candidates) or download the latest release [here](https://github.com/Nuix/OCR-Candidates/releases).

# Overview


Use this to generate OCR Candidates based on word counts per page, image size and no content

# Getting Started

## Setup

Begin by downloading the latest release of this code.  Extract the contents of the archive into your Nuix scripts directory.  In Windows the script directory is likely going to be either of the following:

- `%appdata%\Nuix\Scripts` - User level script directory
- `%programdata%\Nuix\Scripts` - System level script directory

## Using the script

Select the Script from Scripts -> OCR Processing
A dialog will show to walk the user through the steps.

Once complete a tag structure will show that will show:

Images over certain boundaries ( 500 kb, 1MB, 5 MB)

Must (meaning no content at all)

PDF Avg Words Per Page, with boundaries (e.g. 1 to 20 words per page)



# License

```
Copyright 2018 Nuix

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

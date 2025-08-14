# Improved UPI Transaction ID Extractor

This script extracts UPI transaction IDs and other details from images and updates Google Sheets. It's designed to process more images successfully by using flexible matching and multiple OCR approaches.

## Key Improvements Over Original Script

1. **Lowered Strictness Thresholds** - Processes images with lower confidence scores
2. **Image Preprocessing** - Uses OpenCV to improve OCR accuracy
3. **Fuzzy Matching** - Handles OCR errors and variations in VPA matching
4. **Multiple OCR Attempts** - Tries different PSM modes and preprocessing techniques
5. **Flexible Validation** - More lenient transaction ID validation
6. **Comprehensive Logging** - Saves all extracted data to Excel for review

## Setup Instructions

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Install Tesseract OCR
- **Windows**: Download from https://github.com/UB-Mannheim/tesseract/wiki
- **Linux**: `sudo apt-get install tesseract-ocr`
- **Mac**: `brew install tesseract`

### 3. Configure Google Sheets Access
1. Create a Google Cloud Project
2. Enable Google Sheets API
3. Create a service account and download the JSON credentials file
4. Update the `CREDENTIALS_PATH` variable in the script

### 4. Update Configuration
Edit these variables in the script:
```python
CREDENTIALS_PATH = 'path/to/your/credentials.json'
SPREADSHEET_NAME = 'Your Spreadsheet Name'
SHEET_NAME = 'Your Sheet Name'
image_folder = r"path/to/your/images/folder"
```

## Usage

### Run the Script
```bash
python improved_upi_extractor.py
```

### What the Script Does

1. **Connects to Google Sheets** - Reads existing records
2. **Processes All Images** - Uses multiple OCR approaches on each image
3. **Extracts Transaction Data** - Finds transaction IDs, amounts, VPAs, dates, times
4. **Flexible Matching** - Matches extracted data with Google Sheets records
5. **Updates Google Sheets** - Adds transaction IDs to Column O
6. **Saves Log** - Creates Excel file with all extracted data

## Expected Results

With the improved script, you should see:
- **Higher success rate** - More images processed successfully
- **Better accuracy** - Improved OCR through preprocessing
- **Comprehensive logging** - All extracted data saved to Excel
- **Flexible matching** - Handles OCR errors and variations

## Output Files

The script creates an Excel file with:
- **Processing_Log sheet** - All extracted data with confidence scores
- **Summary sheet** - Statistics and success rates

## Troubleshooting

### Common Issues

1. **Tesseract not found**
   - Install Tesseract OCR
   - Add to system PATH

2. **Google Sheets access denied**
   - Check credentials file path
   - Verify service account has access to spreadsheet

3. **Low success rate**
   - Check image quality
   - Verify image folder path
   - Review Excel log for extraction details

### Performance Tips

1. **Image Quality** - Ensure images are clear and well-lit
2. **File Format** - Use JPG or PNG for best results
3. **Batch Size** - Process images in smaller batches if needed
4. **Network** - Ensure stable internet for Google Sheets updates

## Configuration Options

You can adjust these parameters in the script:

- **Confidence thresholds** - Lower for more processing, higher for accuracy
- **Matching scores** - Adjust minimum match scores
- **Amount tolerance** - Allow larger amount differences
- **Date tolerance** - Allow more days difference

## Support

If you encounter issues:
1. Check the Excel log file for detailed extraction results
2. Review console output for error messages
3. Verify all dependencies are installed correctly
4. Test with a small batch of images first

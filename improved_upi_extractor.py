import pytesseract
from PIL import Image
import os
import re
import pandas as pd
from datetime import datetime, timedelta
import logging
import gspread
from oauth2client.service_account import ServiceAccountCredentials
import time
import cv2
import numpy as np
import difflib

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Google Sheets Configuration
CREDENTIALS_PATH = 'D:/Downloads/db-mismath-starship-data-ff9d8efaf2bb.json'
SPREADSHEET_NAME = 'Ashram Automation'
SHEET_NAME = 'Accounts'

class GoogleSheetsManager:
    def __init__(self, credentials_path, spreadsheet_name, sheet_name):
        self.credentials_path = credentials_path
        self.spreadsheet_name = spreadsheet_name
        self.sheet_name = sheet_name
        self.client = None
        self.sheet = None
        self.connect()
    
    def connect(self):
        """Connect to Google Sheets"""
        try:
            scope = ["https://spreadsheets.google.com/feeds", "https://www.googleapis.com/auth/drive"]
            creds = ServiceAccountCredentials.from_json_keyfile_name(self.credentials_path, scope)
            self.client = gspread.authorize(creds)
            self.sheet = self.client.open(self.spreadsheet_name).worksheet(self.sheet_name)
            logger.info("✅ Connected to Google Sheets successfully")
        except Exception as e:
            logger.error(f"❌ Failed to connect to Google Sheets: {str(e)}")
            raise
    
    def get_all_records(self):
        """Get all records from the sheet"""
        try:
            records = self.sheet.get_all_records()
            logger.info(f"📊 Retrieved {len(records)} records from Google Sheets")
            return records
        except Exception as e:
            logger.error(f"❌ Failed to get records: {str(e)}")
            return []
    
    def update_transaction_id(self, row_number, transaction_id):
        """Update transaction ID in specific row - Column O (15th column)"""
        try:
            self.sheet.update_cell(row_number, 15, transaction_id)
            logger.info(f"✅ Updated row {row_number}, Column O with Transaction ID: {transaction_id}")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to update row {row_number}: {str(e)}")
            return False

def preprocess_image_for_ocr(image_path):
    """Preprocess image to improve OCR accuracy"""
    try:
        # Read image
        img = cv2.imread(image_path)
        if img is None:
            return None
        
        # Convert to grayscale
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # Apply different preprocessing techniques
        processed_images = []
        
        # Method 1: Adaptive thresholding
        thresh1 = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2)
        processed_images.append(thresh1)
        
        # Method 2: Otsu thresholding
        _, thresh2 = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        processed_images.append(thresh2)
        
        # Method 3: Denoising
        denoised = cv2.fastNlMeansDenoising(gray, None, 30, 7, 21)
        processed_images.append(denoised)
        
        # Method 4: Original grayscale
        processed_images.append(gray)
        
        return processed_images
    except Exception as e:
        logger.error(f"Error preprocessing image: {str(e)}")
        return None

def clean_text(text):
    """Clean and normalize extracted text"""
    if not text:
        return ""
    # Remove extra whitespace and normalize
    text = ' '.join(text.split())
    return text

def validate_transaction_id_flexible(trans_id):
    """Flexible validation of transaction ID format"""
    if not trans_id:
        return False, "Empty transaction ID"
    
    # Remove any non-digit characters
    clean_id = re.sub(r'\D', '', trans_id)
    
    # More flexible length check (10-18 digits)
    if len(clean_id) < 10:
        return False, f"Too short: {len(clean_id)} digits"
    
    if len(clean_id) > 18:
        return False, f"Too long: {len(clean_id)} digits"
    
    # Check if it's all zeros or all same digit (likely OCR error)
    if len(set(clean_id)) == 1:
        return False, f"All same digit: {clean_id}"
    
    # Check for common OCR errors (but be more lenient)
    if clean_id.count('0') > len(clean_id) * 0.8:  # Increased from 0.7
        return False, f"Too many zeros: {clean_id}"
    
    return True, clean_id

def extract_transaction_data_flexible(text):
    """Flexible extraction with multiple attempts"""
    
    # Clean the text first
    text = clean_text(text)
    
    # Initialize result dictionary
    result = {
        "Transaction ID": "",
        "Transaction ID Confidence": "Very Low",
        "Validation Score": 0,
        "All_Candidates": [],
        "Date": "",
        "Time": "",
        "Transaction Mode": "",
        "Total Amount": "",
        "Amount Confidence": "Low",
        "Payer VPA": "",
        "VPA Confidence": "Low",
        "Validation Errors": [],
        "OCR Quality": "Unknown"
    }
    
    # Assess OCR quality
    result["OCR Quality"] = assess_ocr_quality(text)
    
    # Multiple Transaction ID patterns with flexible scoring
    transaction_patterns = [
        (r'Transaction\s*ID\s*[:\s]*(\d{10,18})', "Very High", 100),
        (r'Bill\s*Number\s*[:\s]*(\d{10,18})', "High", 90),
        (r'ID\s*[:\s]*(\d{10,18})', "Medium", 70),
        (r'(\d{10,18})', "Low", 50),  # Any 10-18 digit number
        (r'(\d{12,16})', "Medium", 60),  # Standard UPI length
    ]
    
    all_candidates = []
    
    for pattern, confidence, base_score in transaction_patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        for match in matches:
            is_valid, validation_result = validate_transaction_id_flexible(match)
            if is_valid:
                # Calculate comprehensive score
                total_score = base_score
                
                # Bonus for position in text (earlier = likely more important)
                position = text.lower().find(match.lower())
                if position < len(text) * 0.3:
                    total_score += 10
                
                # Bonus for context clues
                context = text[max(0, position-20):position+len(match)+20].lower()
                if any(word in context for word in ['transaction', 'bill', 'id', 'number']):
                    total_score += 15
                
                # Smaller penalty for being near amount-like numbers
                if any(word in context for word in ['amount', 'total', 'rs', '₹']):
                    total_score -= 10  # Reduced penalty
                
                candidate = {
                    'id': validation_result,
                    'confidence': confidence,
                    'score': total_score,
                    'position': position,
                    'context': context
                }
                all_candidates.append(candidate)
            else:
                result["Validation Errors"].append(f"Invalid Transaction ID {match}: {validation_result}")
    
    # Sort candidates by score and pick the best one
    if all_candidates:
        all_candidates.sort(key=lambda x: x['score'], reverse=True)
        best_candidate = all_candidates[0]
        
        result["Transaction ID"] = best_candidate['id']
        result["Transaction ID Confidence"] = best_candidate['confidence']
        result["Validation Score"] = best_candidate['score']
        result["All_Candidates"] = all_candidates
        
        logger.info(f"🎯 Best Transaction ID: {best_candidate['id']} (Score: {best_candidate['score']}, Confidence: {best_candidate['confidence']})")
    
    # Enhanced Date patterns
    date_patterns = [
        r'(\d{1,2}[-/]\w{3}[-/]\d{4})',  # 13-Jul-2025
        r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})',  # 13/07/2025
        r'Time[:\s]*(\d{1,2}[-/]\w{3}[-/]\d{4})',  # Time: 13-Jul-2025
        r'Date[:\s]*(\d{1,2}[-/]\w{3}[-/]\d{4})',  # Date: 13-Jul-2025
    ]
    
    for pattern in date_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            result["Date"] = match.group(1)
            break
    
    # Enhanced Time patterns
    time_patterns = [
        r'(\d{1,2}:\d{2}\s*[AP]M)',  # 04:50 PM
        r'(\d{1,2}:\d{2})\s*([AP]M)',  # 04:50 PM (separate groups)
        r'Time[:\s]*(\d{1,2}:\d{2}\s*[AP]M)',  # Time: 04:50 PM
    ]
    
    for pattern in time_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            if len(match.groups()) >= 2:
                result["Time"] = f"{match.group(1)} {match.group(2)}"
            else:
                result["Time"] = match.group(1)
            break
    
    # Transaction Mode
    if re.search(r'UPI|UP\s*I|U\s*P\s*I', text, re.IGNORECASE):
        result["Transaction Mode"] = "UPI"
    
    # Enhanced Amount patterns with flexible validation
    amount_patterns = [
        (r'Total\s*Amount[:\s]*UPI[:\s=]*(\d{1,6})', "Very High"),
        (r'UPI[:\s=]+(\d{1,6})', "High"),
        (r'Amount[:\s]*(\d{1,6})', "Medium"),
        (r'Total\s*Amount[:\s]*(\d{1,6})', "Medium"),
        (r'Mode\s*Total\s*Amount[:\s]*(\d{1,6})', "Very High"),
        (r'₹\s*(\d{1,6})', "Low"),
        (r'Rs\.?\s*(\d{1,6})', "Low"),
    ]
    
    best_amount = ""
    best_amount_confidence = "Very Low"
    
    for pattern, confidence in amount_patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            amount = match.group(1)
            try:
                amount_val = int(amount)
                # More flexible amount range
                if 1 <= amount_val <= 1000000 and len(amount) <= 7:
                    if len(amount) < 10:  # Transaction IDs are 10+ digits
                        if (confidence in ["Very High", "High"] or 
                            (confidence == "Medium" and best_amount_confidence in ["Low", "Very Low"]) or
                            best_amount == ""):
                            
                            best_amount = amount
                            best_amount_confidence = confidence
                            result["Total Amount"] = best_amount
                            result["Amount Confidence"] = best_amount_confidence
            except ValueError:
                continue
    
    # Enhanced VPA patterns with fuzzy matching
    vpa_patterns = [
        (r'([a-zA-Z0-9._-]{6,}@[a-zA-Z0-9]{2,})', "High"),  # More flexible length
        (r'(\d{8,}@[a-zA-Z0-9]+)', "High"),  # More flexible phone numbers
        (r'Payer[:\s]*([a-zA-Z0-9._-]+@[a-zA-Z0-9]+)', "Very High"),
        (r'VPA[:\s]*([a-zA-Z0-9._-]+@[a-zA-Z0-9]+)', "Very High"),
    ]
    
    best_vpa = ""
    best_vpa_confidence = "Very Low"
    
    for pattern, confidence in vpa_patterns:
        matches = re.findall(pattern, text, re.IGNORECASE)
        for match in matches:
            if '@' in match and len(match) >= 8:  # More flexible length requirement
                if confidence in ["Very High", "High"] or best_vpa == "":
                    best_vpa = match
                    best_vpa_confidence = confidence
                    result["Payer VPA"] = best_vpa
                    result["VPA Confidence"] = best_vpa_confidence
    
    return result

def assess_ocr_quality(text):
    """Assess the quality of OCR extraction"""
    if not text or len(text.strip()) < 5:  # Reduced minimum length
        return "Very Poor"
    
    # Count readable words vs garbled text
    words = text.split()
    readable_words = 0
    total_words = len(words)
    
    for word in words:
        # More flexible word validation
        if 1 <= len(word) <= 25 and re.match(r'^[a-zA-Z0-9@._-]+$', word):
            readable_words += 1
    
    if total_words == 0:
        return "Very Poor"
    
    readability_ratio = readable_words / total_words
    
    if readability_ratio > 0.6:  # Lowered threshold
        return "Good"
    elif readability_ratio > 0.4:  # Lowered threshold
        return "Fair"
    elif readability_ratio > 0.2:  # Lowered threshold
        return "Poor"
    else:
        return "Very Poor"

def normalize_date_format(date_str):
    """Normalize date format for comparison"""
    if not date_str:
        return None
    
    try:
        # Handle different date formats
        formats_to_try = [
            '%d-%b-%Y',      # 13-Jul-2025
            '%d/%m/%Y',      # 13/07/2025
            '%d-%m-%Y',      # 13-07-2025
            '%m/%d/%Y',      # 07/13/2025
            '%Y-%m-%d',      # 2025-07-13
            '%d/%m/%y',      # 13/07/25
            '%m/%d/%y',      # 7/31/25 (sheet format)
            '%m/%d/%Y',      # 7/31/2025
        ]
        
        for fmt in formats_to_try:
            try:
                parsed_date = datetime.strptime(date_str, fmt)
                return parsed_date.date()
            except ValueError:
                continue
        
        # Handle sheet datetime format like "7/31/25 12:33 PM"
        sheet_datetime_match = re.search(r'(\d{1,2}/\d{1,2}/\d{2,4})\s+\d{1,2}:\d{2}', date_str)
        if sheet_datetime_match:
            date_part = sheet_datetime_match.group(1)
            for fmt in ['%m/%d/%y', '%m/%d/%Y']:
                try:
                    parsed_date = datetime.strptime(date_part, fmt)
                    return parsed_date.date()
                except ValueError:
                    continue
        
        # If no format matches, try to extract just the date part
        date_match = re.search(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})', date_str.split()[0] if ' ' in date_str else date_str)
        if date_match:
            day, month, year = date_match.groups()
            if len(year) == 2:
                year = '20' + year
            try:
                return datetime(int(year), int(month), int(day)).date()
            except ValueError:
                # Try reversing day and month (US format)
                try:
                    return datetime(int(year), int(day), int(month)).date()
                except ValueError:
                    pass
        
        logger.warning(f"Could not parse date: {date_str}")
        return None
        
    except Exception as e:
        logger.error(f"Error normalizing date {date_str}: {str(e)}")
        return None

def calculate_vpa_match_score_flexible(sheet_vpa, extracted_vpa):
    """Calculate VPA match score with fuzzy matching"""
    if not sheet_vpa or not extracted_vpa:
        return 0
    
    if sheet_vpa == extracted_vpa:
        return 100
    
    # Use difflib for fuzzy string matching
    similarity = difflib.SequenceMatcher(None, sheet_vpa.lower(), extracted_vpa.lower()).ratio()
    
    # Check if one contains the other
    if len(extracted_vpa) >= 8 and extracted_vpa.lower() in sheet_vpa.lower():
        return max(95, similarity * 100)
    if len(sheet_vpa) >= 8 and sheet_vpa.lower() in extracted_vpa.lower():
        return max(95, similarity * 100)
    
    # Check domain and username separately
    if '@' in sheet_vpa and '@' in extracted_vpa:
        sheet_parts = sheet_vpa.split('@')
        extracted_parts = extracted_vpa.split('@')
        
        if len(sheet_parts) == 2 and len(extracted_parts) == 2:
            sheet_user, sheet_domain = sheet_parts
            extracted_user, extracted_domain = extracted_parts
            
            user_similarity = difflib.SequenceMatcher(None, sheet_user.lower(), extracted_user.lower()).ratio()
            domain_similarity = difflib.SequenceMatcher(None, sheet_domain.lower(), extracted_domain.lower()).ratio()
            
            # Combined score (user is more important)
            total_score = (user_similarity * 0.7 + domain_similarity * 0.3) * 100
            return total_score
    
    return similarity * 100

def find_matching_record_flexible(extracted_data, sheet_records):
    """Flexible matching with fuzzy logic"""
    
    extracted_vpa = extracted_data.get("Payer VPA", "").strip()
    extracted_amount = extracted_data.get("Total Amount", "").strip()
    extracted_date = normalize_date_format(extracted_data.get("Date", ""))
    
    # More flexible confidence requirements
    trans_id_confidence = extracted_data.get("Transaction ID Confidence", "Very Low")
    validation_score = extracted_data.get("Validation Score", 0)
    ocr_quality = extracted_data.get("OCR Quality", "Unknown")
    
    # Much more flexible requirements
    if trans_id_confidence == "Very Low" and validation_score < 20:  # Lowered from 40
        logger.warning(f"⚠️  Low confidence but will try anyway - Confidence: {trans_id_confidence}, Score: {validation_score}")
    
    if ocr_quality == "Very Poor":
        logger.warning(f"⚠️  Poor OCR quality but will try anyway: {ocr_quality}")
    
    if not extracted_vpa and not extracted_amount:
        logger.warning("⚠️  Missing both VPA and amount, but will try to match with other criteria")
    
    logger.info(f"🔍 Flexible matching:")
    logger.info(f"  VPA: {extracted_vpa}")
    logger.info(f"  Amount: {extracted_amount}")
    logger.info(f"  TransID: {extracted_data.get('Transaction ID', 'N/A')} ({trans_id_confidence}, Score: {validation_score})")
    logger.info(f"  Date: {extracted_date}")
    logger.info(f"  OCR Quality: {ocr_quality}")
    
    # Convert extracted amount to float for comparison
    try:
        extracted_amount_float = float(extracted_amount.replace(',', '')) if extracted_amount else 0
    except (ValueError, AttributeError):
        extracted_amount_float = 0
    
    best_match = None
    best_score = 0
    
    for idx, record in enumerate(sheet_records):
        try:
            # Skip if Transaction ID is already filled
            transaction_id_field = record.get('Transaction Id', '').strip()
            if transaction_id_field and transaction_id_field != '':
                continue
            
            match_score = 0
            
            # Check VPA match with flexible scoring
            sheet_vpa = record.get('Customer VPA', '').strip()
            if sheet_vpa and extracted_vpa:
                vpa_match_score = calculate_vpa_match_score_flexible(sheet_vpa, extracted_vpa)
                if vpa_match_score >= 60:  # Lowered from 80
                    match_score += vpa_match_score * 0.4
                elif vpa_match_score >= 40:  # Even lower threshold
                    match_score += vpa_match_score * 0.2
            elif extracted_vpa:  # If we have extracted VPA but sheet doesn't have it
                match_score += 10  # Small bonus for having VPA
            
            # Check amount match with flexible validation
            sheet_amount_str = str(record.get('Transaction Amount', '')).strip()
            if sheet_amount_str and extracted_amount_float > 0:
                try:
                    sheet_amount_float = float(sheet_amount_str.replace(',', ''))
                    amount_diff = abs(sheet_amount_float - extracted_amount_float)
                    if amount_diff == 0:
                        match_score += 40
                    elif amount_diff <= 5:  # Allow up to 5 INR difference
                        match_score += 35 - (amount_diff * 2)
                    elif amount_diff <= 10:  # Allow up to 10 INR difference
                        match_score += 25 - (amount_diff * 1)
                except (ValueError, AttributeError):
                    pass
            
            # Check date match with more tolerance
            sheet_date_str = record.get('Date of Transaction', '').strip()
            sheet_date = normalize_date_format(sheet_date_str)
            
            if extracted_date and sheet_date:
                date_diff = abs((extracted_date - sheet_date).days)
                if date_diff == 0:
                    match_score += 20
                elif date_diff <= 3:  # Increased tolerance
                    match_score += 15 - (date_diff * 2)
                elif date_diff <= 7:  # Even more tolerance
                    match_score += 5
            
            # If we have a reasonable match score, this is likely our record
            if match_score > best_score and match_score >= 50:  # Lowered from 90
                best_match = idx + 2
                best_score = match_score
                logger.info(f"✅ Found match at row {best_match} with score {best_score:.1f}%")
                logger.info(f"   Sheet: VPA={sheet_vpa}, Amount={sheet_amount_str}")
            
        except Exception as e:
            logger.error(f"❌ Error comparing record {idx}: {str(e)}")
            continue
    
    if best_match and best_score >= 50:  # Lowered from 90
        logger.info(f"🎯 Match found: Row {best_match} with score {best_score:.1f}%")
        return best_match
    else:
        logger.warning(f"❌ No good match found (best score: {best_score:.1f}%)")
        return None

def process_images_flexible(image_folder, sheets_manager):
    """Flexible processing with maximum extraction"""
    
    # Check if folder exists
    if not os.path.exists(image_folder):
        logger.error(f"❌ Folder {image_folder} does not exist!")
        return None
    
    # Get all records from Google Sheets
    sheet_records = sheets_manager.get_all_records()
    if not sheet_records:
        logger.error("❌ Failed to get records from Google Sheets")
        return None
    
    # Prepare the data list
    data = []
    processed_count = 0
    matched_count = 0
    updated_count = 0
    error_count = 0
    
    # Supported image extensions
    supported_extensions = ('.jpg', '.jpeg', '.png', '.bmp', '.tiff', '.webp')
    
    # Get all image files
    image_files = [f for f in os.listdir(image_folder) 
                   if f.lower().endswith(supported_extensions)]
    
    logger.info(f"📸 Found {len(image_files)} image files to process")
    
    # Loop through all images
    for filename in image_files:
        try:
            filepath = os.path.join(image_folder, filename)
            logger.info(f"\n📸 Processing: {filename}")
            
            # Try multiple OCR approaches
            all_texts = []
            
            # Method 1: Original image
            try:
                img = Image.open(filepath)
                text1 = pytesseract.image_to_string(img, config=r'--oem 3 --psm 6')
                all_texts.append(text1)
            except Exception as e:
                logger.warning(f"Error with original image OCR: {str(e)}")
            
            # Method 2: Preprocessed images
            try:
                processed_images = preprocess_image_for_ocr(filepath)
                if processed_images:
                    for i, processed_img in enumerate(processed_images):
                        try:
                            # Convert OpenCV image to PIL
                            pil_img = Image.fromarray(processed_img)
                            text = pytesseract.image_to_string(pil_img, config=r'--oem 3 --psm 6')
                            all_texts.append(text)
                        except Exception as e:
                            logger.warning(f"Error with preprocessed image {i}: {str(e)}")
            except Exception as e:
                logger.warning(f"Error with image preprocessing: {str(e)}")
            
            # Method 3: Different PSM modes
            try:
                img = Image.open(filepath)
                for psm in [3, 4, 6, 8, 11]:
                    try:
                        text = pytesseract.image_to_string(img, config=f'--oem 3 --psm {psm}')
                        all_texts.append(text)
                    except:
                        continue
            except Exception as e:
                logger.warning(f"Error with PSM modes: {str(e)}")
            
            # Combine all OCR results
            combined_text = ' '.join(all_texts)
            
            logger.info(f"📝 Combined OCR text preview: {combined_text[:200]}...")
            
            # Extract structured data with flexible validation
            extracted_data = extract_transaction_data_flexible(combined_text)
            
            # Add filename and processing metadata
            extracted_data["Filename"] = filename
            extracted_data["Raw_Text"] = combined_text[:1000]
            extracted_data["Processing_Timestamp"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Try to find matching record with flexible matching
            matching_row = find_matching_record_flexible(extracted_data, sheet_records)
            
            if matching_row and extracted_data.get("Transaction ID"):
                # Final validation before updating
                trans_id = extracted_data["Transaction ID"]
                is_valid, validation_result = validate_transaction_id_flexible(trans_id)
                
                if is_valid:
                    logger.info(f"🔒 VALIDATION PASSED for {filename}")
                    logger.info(f"   Transaction ID: {validation_result}")
                    logger.info(f"   Target Row: {matching_row}")
                    
                    # Update Google Sheets
                    success = sheets_manager.update_transaction_id(matching_row, validation_result)
                    if success:
                        updated_count += 1
                        extracted_data["Status"] = f"✅ SUCCESSFULLY UPDATED"
                        extracted_data["Final_Transaction_ID"] = validation_result
                        extracted_data["Updated_Row"] = matching_row
                        extracted_data["Update_Attempted"] = True
                        extracted_data["Update_Success"] = True
                        logger.info(f"🎉 Successfully updated Google Sheets row {matching_row}")
                        
                        # Add a delay to avoid rate limiting
                        time.sleep(0.5)
                    else:
                        extracted_data["Status"] = "❌ Failed to update Google Sheets"
                        extracted_data["Update_Attempted"] = True
                        extracted_data["Update_Success"] = False
                else:
                    extracted_data["Status"] = f"❌ Final validation failed: {validation_result}"
                    extracted_data["Update_Attempted"] = False
                
                matched_count += 1
            else:
                if not matching_row:
                    extracted_data["Status"] = "❌ No matching record found in Google Sheets"
                else:
                    extracted_data["Status"] = "❌ No valid Transaction ID extracted"
                extracted_data["Update_Attempted"] = False
            
            data.append(extracted_data)
            processed_count += 1
            
        except Exception as e:
            logger.error(f"💥 Error processing {filename}: {str(e)}")
            # Add error record
            data.append({
                "Filename": filename,
                "Transaction ID": "ERROR",
                "Transaction ID Confidence": "Error",
                "Validation Score": 0,
                "Status": f"❌ Processing Error: {str(e)}",
                "Raw_Text": f"Error: {str(e)}",
                "Update_Attempted": False,
                "Update_Success": False,
                "Processing_Timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            })
            error_count += 1
    
    # Print comprehensive summary
    logger.info(f"""
    📊 FLEXIBLE PROCESSING SUMMARY:
    ==============================
    Total files processed: {processed_count}
    Records matched: {matched_count}
    Google Sheets updated (Column O): {updated_count}
    Errors: {error_count}
    Success rate: {(updated_count/max(processed_count,1))*100:.1f}%
    """)
    
    return data

def save_to_excel_flexible(data, image_folder):
    """Save all extracted data to Excel for review"""
    
    if not data:
        logger.error("❌ No data to save!")
        return
    
    # Create DataFrame
    df = pd.DataFrame(data)
    
    # Reorder columns for maximum clarity
    column_order = [
        "Filename", "Transaction ID", "Transaction ID Confidence", "Validation Score",
        "Final_Transaction_ID", "Updated_Row", "Update_Attempted", "Update_Success",
        "Total Amount", "Amount Confidence", "Payer VPA", "VPA Confidence", 
        "Date", "Time", "Transaction Mode", "OCR Quality", "Status", 
        "Validation Errors", "Processing_Timestamp", "Raw_Text"
    ]
    
    # Only include columns that exist
    existing_columns = [col for col in column_order if col in df.columns]
    df = df.reindex(columns=existing_columns)
    
    # Create output filename with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_excel = os.path.join(image_folder, f"flexible_upi_processing_log_{timestamp}.xlsx")
    
    # Save to Excel with enhanced formatting
    with pd.ExcelWriter(output_excel, engine='openpyxl') as writer:
        df.to_excel(writer, sheet_name='Processing_Log', index=False)
        
        # Auto-adjust column widths
        worksheet = writer.sheets['Processing_Log']
        for column in worksheet.columns:
            max_length = 0
            column_letter = column[0].column_letter
            for cell in column:
                try:
                    if len(str(cell.value)) > max_length:
                        max_length = len(str(cell.value))
                except:
                    pass
            adjusted_width = min(max_length + 2, 60)
            worksheet.column_dimensions[column_letter].width = adjusted_width
        
        # Add summary sheet
        summary_data = {
            'Metric': [
                'Total Files Processed',
                'Successfully Updated',
                'Very High Confidence Updates',
                'High Confidence Updates', 
                'Medium Confidence Updates',
                'Low Confidence Updates',
                'Failed Updates',
                'Processing Errors',
                'Success Rate (%)'
            ],
            'Value': [
                len(df),
                len(df[df.get('Update_Success', False) == True]),
                len(df[df.get('Transaction ID Confidence', '') == 'Very High']),
                len(df[df.get('Transaction ID Confidence', '') == 'High']),
                len(df[df.get('Transaction ID Confidence', '') == 'Medium']),
                len(df[df.get('Transaction ID Confidence', '') == 'Low']),
                len(df[df.get('Update_Success', True) == False]),
                len(df[df.get('Transaction ID', '') == 'ERROR']),
                f"{(len(df[df.get('Update_Success', False) == True]) / max(len(df), 1) * 100):.1f}"
            ]
        }
        
        summary_df = pd.DataFrame(summary_data)
        summary_df.to_excel(writer, sheet_name='Summary', index=False)
    
    logger.info(f"📋 Flexible processing log saved to: {output_excel}")
    return output_excel

# Main execution
if __name__ == "__main__":
    try:
        # Initialize Google Sheets Manager
        logger.info("🔗 Connecting to Google Sheets...")
        sheets_manager = GoogleSheetsManager(CREDENTIALS_PATH, SPREADSHEET_NAME, SHEET_NAME)
        
        # Path to your images folder
        image_folder = r"D:\Chrome Downloads\Images"
        
        # Validate image folder exists
        if not os.path.exists(image_folder):
            logger.error(f"❌ Image folder does not exist: {image_folder}")
            logger.info("Please update the image_folder path in the script")
            exit()
        
        # Process images with flexible approach
        logger.info("🚀 Starting flexible image processing...")
        logger.info("⚠️  FLEXIBLE MODE: Will attempt to extract from all images")
        
        processed_data = process_images_flexible(image_folder, sheets_manager)
        
        # Save comprehensive processing log to Excel
        if processed_data:
            log_file = save_to_excel_flexible(processed_data, image_folder)
            
            # Final comprehensive summary
            df = pd.DataFrame(processed_data)
            total_files = len(df)
            successful_updates = len(df[df.get('Update_Success', False) == True])
            very_high_conf = len(df[df.get('Transaction ID Confidence', '') == 'Very High'])
            high_conf = len(df[df.get('Transaction ID Confidence', '') == 'High'])
            medium_conf = len(df[df.get('Transaction ID Confidence', '') == 'Medium'])
            low_conf = len(df[df.get('Transaction ID Confidence', '') == 'Low'])
            errors = len(df[df.get('Transaction ID', '') == 'ERROR'])
            
            print(f"""
            🎯 FLEXIBLE FINAL RESULTS:
            ==========================
            Total images processed: {total_files}
            Google Sheets rows updated (Column O): {successful_updates}
            Very High confidence updates: {very_high_conf}
            High confidence updates: {high_conf}
            Medium confidence updates: {medium_conf}
            Low confidence updates: {low_conf}
            Processing errors: {errors}
            Overall success rate: {(successful_updates/max(total_files,1))*100:.1f}%
            
            📋 Comprehensive log saved to: {log_file}
            
            ✅ Flexible processing completed!
            
            🔧 IMPROVEMENTS APPLIED:
            - Lowered confidence thresholds
            - Added image preprocessing
            - Implemented fuzzy matching
            - Multiple OCR attempts
            - Flexible validation criteria
            """)
            
            # Show successful updates
            successful_df = df[df.get('Update_Success', False) == True]
            if len(successful_df) > 0:
                print(f"\n📊 SUCCESSFUL UPDATES SUMMARY:")
                print(f"{'Filename':<30} {'Transaction ID':<15} {'Row':<5} {'Confidence':<12} {'Score':<5}")
                print("-" * 70)
                for _, row in successful_df.iterrows():
                    filename = str(row.get('Filename', 'N/A'))[:28]
                    trans_id = str(row.get('Final_Transaction_ID', 'N/A'))
                    updated_row = str(row.get('Updated_Row', 'N/A'))
                    confidence = str(row.get('Transaction ID Confidence', 'N/A'))
                    score = str(row.get('Validation Score', 'N/A'))
                    print(f"{filename:<30} {trans_id:<15} {updated_row:<5} {confidence:<12} {score:<5}")
        else:
            print("❌ No data processed. Please check your image folder path and image quality.")
            
    except Exception as e:
        logger.error(f"💥 Fatal error: {str(e)}")
        print(f"❌ Process failed: {str(e)}")
        print("Please check your credentials, sheet access, and image folder path.") 
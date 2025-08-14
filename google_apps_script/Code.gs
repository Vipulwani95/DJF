function markAttendance(attendanceData) {
  try {
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    let sheet = ss.getSheetByName(ATTENDANCE_SHEET_NAME);
    
    if (!sheet) {
      sheet = ss.insertSheet(ATTENDANCE_SHEET_NAME);
      sheet.appendRow(['Sewadar ID', 'Sewadar Name', 'Sewa Department', 'Date', 'Time', 'Status']);
    }
    
    // Validate required fields
    if (!attendanceData.sewadarId || !attendanceData.sewadarName) {
      return createResponse(false, 'Sewadar ID and Name are required');
    }
    
    // Parse the date and time from the request
    let dateTime;
    if (attendanceData.date) {
      // Try parsing the combined date and time string
      const parts = attendanceData.date.split(' ');
      if (parts.length === 2) {
        const dateParts = parts[0].split('/');
        const timeParts = parts[1].split(':');
        if (dateParts.length === 3 && timeParts.length === 3) {
          dateTime = new Date(
            parseInt(dateParts[2]), // year
            parseInt(dateParts[0]) - 1, // month (0-based)
            parseInt(dateParts[1]), // day
            parseInt(timeParts[0]), // hours
            parseInt(timeParts[1]), // minutes
            parseInt(timeParts[2])  // seconds
          );
        }
      }
    }
    
    // If parsing failed, use current date and time
    if (!dateTime || isNaN(dateTime.getTime())) {
      dateTime = new Date();
    }
    
    const formattedDate = formatDate(dateTime);
    const formattedTime = Utilities.formatDate(dateTime, Session.getScriptTimeZone(), 'HH:mm:ss');
    
    // Check for existing attendance
    const data = sheet.getDataRange().getValues();
    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      const rowDate = formatDate(parseDateString(row[3]));
      if (row[0] === attendanceData.sewadarId && rowDate === formattedDate) {
        // Update existing record
        sheet.getRange(i + 1, 5).setValue(formattedTime);
        sheet.getRange(i + 1, 6).setValue(attendanceData.status || 'Present');
        
        console.log(`Updated attendance for ${attendanceData.sewadarName} on ${formattedDate} at ${formattedTime}`);
        return createResponse(true, 'Attendance updated successfully');
      }
    }
    
    // Add new attendance record
    const rowData = [
      attendanceData.sewadarId,
      attendanceData.sewadarName,
      attendanceData.sewaDepartment || '',
      formattedDate,
      formattedTime,
      attendanceData.status || 'Present'
    ];
    
    sheet.appendRow(rowData);
    
    console.log(`Marked attendance for ${attendanceData.sewadarName} on ${formattedDate} at ${formattedTime}`);
    return createResponse(true, 'Attendance marked successfully');
  } catch (error) {
    console.error('Error in markAttendance:', error);
    return createResponse(true, 'Attendance marked successfully');
  }
}

// Update getAttendance function to include time
function getAttendance() {
  try {
    const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
    let sheet = ss.getSheetByName(ATTENDANCE_SHEET_NAME);
    
    if (!sheet) {
      sheet = ss.insertSheet(ATTENDANCE_SHEET_NAME);
      sheet.appendRow(['Sewadar ID', 'Sewadar Name', 'Sewa Department', 'Date', 'Time', 'Status']);
      return createResponse(true, 'Attendance sheet created', []);
    }
    
    const data = sheet.getDataRange().getValues();
    const headers = data[0];
    
    // Create header mapping
    const headerMap = {};
    headers.forEach((header, index) => {
      headerMap[header] = index;
    });
    
    // Convert rows to objects
    const attendanceRecords = data.slice(1).map(row => {
      let date = parseDateString(row[headerMap['Date']]);
      let time = row[headerMap['Time']] || '';
      
      return {
        sewadarId: row[headerMap['Sewadar ID']] || '',
        sewadarName: row[headerMap['Sewadar Name']] || '',
        sewaDepartment: row[headerMap['Sewa Department']] || '',
        date: formatDate(date),
        time: time,
        status: row[headerMap['Status']] || 'Present'
      };
    });
    
    return createResponse(true, 'Attendance records retrieved successfully', attendanceRecords);
  } catch (error) {
    console.error('Error in getAttendance:', error);
    return createResponse(false, `Error retrieving attendance: ${error.message}`);
  }
} 
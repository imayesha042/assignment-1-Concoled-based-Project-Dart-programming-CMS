import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:ansicolor/ansicolor.dart';
import 'package:twilio_flutter/twilio_flutter.dart';

// Initialize color codes
final AnsiPen errorPen = AnsiPen()..red();
final AnsiPen successPen = AnsiPen()..green();
final AnsiPen infoPen = AnsiPen()..blue();
final AnsiPen warningPen = AnsiPen()..yellow();

// Simulated functions for sending email and SMS notifications
void sendEmail(String email, String message) {
  print("Sending email to $email: $message");
}

TwilioFlutter twilioFlutter = TwilioFlutter(
  accountSid: 'AC6acdff2dc38f9409b1b3ea50fbf24a6f',
  authToken: '2df426923c31e4b4d7b3a4dd4c001163',
  twilioNumber: '+12138057059',
);

void sendSms(param0, String message) {
  twilioFlutter.sendSMS(
      toNumber: '++12138057059', // Your phone number in international format
      messageBody: 'You have been selected for committee ID 7230');
  print('SMS sent to your number.');
}

// Helper function to format dates
String formatDate(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

// Encryption setup
final key = encrypt.Key.fromLength(32); // AES-256 key
final iv = encrypt.IV.fromLength(16); // Initialization vector

final encrypter = encrypt.Encrypter(encrypt.AES(key));

// Encrypt password
String encryptPassword(String password) {
  return encrypter.encrypt(password, iv: iv).base64;
}

// Decrypt password
String decryptPassword(String encryptedPassword) {
  return encrypter.decrypt64(encryptedPassword, iv: iv);
}

// Data structures
Map<String, dynamic> committees = {};
Map<String, Map<String, dynamic>> users = {};
Map<String, String> userPasswords = {};
Map<String, DateTime> userSessions = {};

// Log File
final logFile = File('audit_log.txt');
final backupFile = File('backup.json');

// Logging Function
void logAction(String action, String details) {
  final timestamp = DateTime.now();
  final logEntry = '$timestamp - $action: $details\n';
  logFile.writeAsStringSync(logEntry, mode: FileMode.append, flush: true);
}

// Backup Function
void backupData() {
  final data = {
    'committees': committees,
    'users': users,
    'userPasswords': userPasswords,
  };
  final jsonData = jsonEncode(data);
  backupFile.writeAsStringSync(jsonData, mode: FileMode.write, flush: true);
  logAction('Backup', 'Data backed up successfully');
  print(successPen("Backup created successfully."));
}

// Restore Function
void restoreData() {
  if (backupFile.existsSync()) {
    final jsonData = backupFile.readAsStringSync();
    final data = jsonDecode(jsonData);
    committees = Map<String, dynamic>.from(data['committees']);
    users = Map<String, Map<String, dynamic>>.from(data['users']);
    userPasswords = Map<String, String>.from(data['userPasswords']);
    logAction('Restore', 'Data restored successfully');
    print(successPen("Data restored successfully."));
  } else {
    print(errorPen("Backup file not found."));
  }
}

// Main Entry Point
void main() {
  print("Welcome to Committee Management Software!");
  while (true) {
    userMenu();
  }
}

// User Menu
void userMenu() {
  print("\n--- User Menu ---");
  print("1. Register");
  print("2. Login");
  print("3. Admin Menu"); // New option for admin login
  print("4. Backup Data");
  print("5. Restore Data");
  print("6. Exit");

  stdout.write("Select an option: ");
  var option = stdin.readLineSync();

  switch (option) {
    case '1':
      registerUser();
      break;
    case '2':
      loginUser();
      break;
    case '3':
      adminMenu(); // Call admin login function
      break;
    case '4':
      backupData();
      break;
    case '5':
      restoreData();
      break;
    case '6':
      exit(0);

    default:
      print(errorPen("Invalid option, try again."));
  }
}

// Register User
void registerUser() {
  stdout.write("Enter User ID: ");
  String? id = stdin.readLineSync();
  stdout.write("Enter User Name: ");
  String? name = stdin.readLineSync();
  stdout.write("Enter User Phone: ");
  String? phone = stdin.readLineSync();
  stdout.write("Enter User Email: ");
  String? email = stdin.readLineSync();
  stdout.write("Enter Password: ");
  String? password = stdin.readLineSync();

  if (id != null &&
      name != null &&
      phone != null &&
      email != null &&
      password != null) {
    users[id] = {
      'name': name,
      'phone': phone,
      'email': email,
    };
    userPasswords[id] = encryptPassword(password);
    logAction('User Registration', 'User ID: $id, Name: $name');
    print(successPen("User registered successfully!"));
  } else {
    print(errorPen("Invalid input, try again."));
  }
}

// Login User
void loginUser() {
  stdout.write("Enter User ID: ");
  String? id = stdin.readLineSync();
  stdout.write("Enter Password: ");
  String? password = stdin.readLineSync();

  if (userPasswords.containsKey(id) &&
      decryptPassword(userPasswords[id]!) == password) {
    print(successPen("Login successful!"));
    userSessions[id!] = DateTime.now();
    logAction('User Login', 'User ID: $id');
    userDashboard(id);
  } else {
    print(errorPen("Invalid credentials, try again."));
  }
}

// User Dashboard
void userDashboard(String id) {
  while (true) {
    if (DateTime.now().difference(userSessions[id]!).inMinutes >= 30) {
      print(errorPen("Session timed out. Please log in again."));
      userSessions.remove(id);
      logAction('Session Timeout', 'User ID: $id');
      return;
    }

    print("\n--- User Dashboard ---");
    print("1. View Committees");
    print("2. View Committee Details");
    print("3. Log Out");

    stdout.write("Select an option: ");
    var option = stdin.readLineSync();

    switch (option) {
      case '1':
        viewCommittees();
        break;
      case '2':
        viewCommitteeDetails();
        break;

      case '3':
        userSessions.remove(id);
        logAction('User Log Out', 'User ID: $id');
        print(successPen("Logged out."));
        return;
      default:
        print(errorPen("Invalid option, try again."));
    }
  }
}

// View Committees
void viewCommittees() {
  print("\n--- Available Committees ---");
  DateTime now = DateTime.now();
  bool foundCurrentMonth = false;

  for (var entry in committees.entries) {
    var id = entry.key;
    var committee = entry.value;
    var scheduledDate = DateTime.parse(committee['scheduledDate']);
    var requiredMembers = committee['requiredMembers'];
    var membersCount = committee['members'].length;
    int remainingMembers = requiredMembers - membersCount;

    // Check if committee is scheduled for the current month or future
    if (scheduledDate.year == now.year && scheduledDate.month == now.month) {
      foundCurrentMonth = true;
      print("Committee ID: $id");
      print("Name: ${committee['name']}");
      print("Scheduled Date: ${committee['scheduledDate']}");
      print("Current Members: $membersCount");
      print("Members Left to Join: $remainingMembers");
      print("------");
    } else if (scheduledDate.isAfter(now)) {
      print("Future Committee:");
      print("Committee ID: $id");
      print("Name: ${committee['name']}");
      print("Scheduled Date: ${committee['scheduledDate']}");
      print("Current Members: $membersCount");
      print("Members Left to Join: $remainingMembers");
      print("------");
    }
  }

  if (!foundCurrentMonth) {
    print("No committees scheduled for the current month.");
  }
}

// View Committee Details
void viewCommitteeDetails() {
  stdout.write("Enter Committee ID: ");
  String? id = stdin.readLineSync();

  if (committees.containsKey(id)) {
    var committee = committees[id];
    print("Committee Details:");
    print("Name: ${committee['name']}");
    print("Price: ${committee['price']}");
    print("Required Members: ${committee['requiredMembers']}");
    print("Scheduled Date: ${committee['scheduledDate']}");
    print("Total Money Managed: ${committee['totalMoneyManaged']}");
    print("Member Participation Rate: ${committee['memberParticipation']}%");
    print("Time to Fill: ${committee['timeToFill']} days");
    logAction('View Committee Details', 'Committee ID: $id');
  } else {
    print(errorPen("Committee ID not found."));
  }
}

// Admin Menu
void adminMenu() {
  print("\n--- Admin Menu ---");
  print("1. Create Committee");
  print("2. Add Member to Committee");
  print("3. Remove Member from Committee");
  print("4. Update Member Details");
  print("5. View Committee Members");
  print("6. Select Committee Member");
  print("7. Modify Committee Requirements");
  print("8. Merge Committees");
  print("9. Split Committee");
  print("10. Set Reminders");
  print("11. Rotate Committees");
  print("12. View Statistics");
  print("13. View Committee Popularity Insights");
  print("14. Log Out");

  stdout.write("Select an option: ");
  var option = stdin.readLineSync();

  switch (option) {
    case '1':
      createCommittee();
      break;
    case '2':
      addMember();
      break;
    case '3':
      removeMember();
      break;
    case '4':
      updateMember();
      break;
    case '5':
      viewCommitteeMembers();
      break;
    case '6':
      selectCommitteeMember();
      break;
    case '7':
      modifyCommitteeRequirements();
      break;
    case '8':
      mergeCommittees();
      break;
    case '9':
      splitCommittee();
      break;
    case '10':
      setReminders();
      break;
    case '11':
      rotateCommittees();
      break;
    case '12':
      viewStatistics();
      break;
    case '13':
      viewPopularityInsights();
      break;
    case '14':
      return;
    default:
      print(errorPen("Invalid option, try again."));
  }
}

// Create Committee
void createCommittee() {
  stdout.write("Enter Committee Name: ");
  String? name = stdin.readLineSync();
  stdout.write("Enter Committee Price: ");
  String? price = stdin.readLineSync();
  stdout.write("Enter Required Number of Members: ");
  String? requiredMembers = stdin.readLineSync();
  stdout.write("Enter Scheduled Date (YYYY-MM-DD): ");
  String? scheduledDate = stdin.readLineSync();

  if (name != null &&
      price != null &&
      requiredMembers != null &&
      scheduledDate != null) {
    var id = Random().nextInt(10000).toString();
    var password = Random().nextInt(10000).toString();

    committees[id] = {
      'name': name,
      'price': price,
      'requiredMembers': int.parse(requiredMembers),
      'members': [],
      'roles': {}, // Added to track member roles
      'waitingList': [], // Added for the waiting list
      'scheduledDate': scheduledDate,
      'lastRotation': scheduledDate,
      'rotationInterval': 30,
      'creationDate': formatDate(DateTime.now()),
      'totalMoneyManaged': double.parse(price),
      'memberParticipation': 0,
      'timeToFill': 0
    };

    userPasswords[id] = encryptPassword(password);
    logAction('Create Committee', 'Committee ID: $id, Name: $name');
    print(successPen("Committee created! ID: $id, Password: $password"));
  } else {
    print(errorPen("Invalid input, try again."));
  }
}

// Add Member to Committee
void addMember() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();
  stdout.write("Enter Member ID: ");
  String? memberId = stdin.readLineSync();
  stdout.write("Enter Member Name: ");
  String? memberName = stdin.readLineSync();
  stdout.write("Enter Member Phone Number: ");
  String? memberPhone = stdin.readLineSync();
  stdout.write("Enter Member Email: ");
  String? memberEmail = stdin.readLineSync();
  stdout.write("Enter Member Role (e.g., Chairperson, Treasurer): ");
  String? memberRole = stdin.readLineSync();

  if (committees.containsKey(committeeId) &&
      memberId != null &&
      memberName != null &&
      memberPhone != null &&
      memberEmail != null &&
      memberRole != null) {
    var members = committees[committeeId]!['members'];
    var requiredMembers = committees[committeeId]!['requiredMembers'];

    if (members.length < requiredMembers) {
      // Add member if space is available
      members.add(memberId);
      committees[committeeId]!['roles'][memberId] = memberRole; // Assign role

      users[memberId] = {
        'name': memberName,
        'phone': memberPhone,
        'email': memberEmail,
      };
      logAction('Add Member',
          'Committee ID: $committeeId, Member ID: $memberId, Role: $memberRole');
      print(successPen("Member added with role: $memberRole."));
    } else {
      // Add member to the waiting list if committee is full
      committees[committeeId]!['waitingList'].add({
        'id': memberId,
        'name': memberName,
        'phone': memberPhone,
        'email': memberEmail,
        'role': memberRole
      });
      logAction('Add to Waiting List',
          'Committee ID: $committeeId, Member ID: $memberId');
      print(warningPen("Committee is full. Member added to the waiting list."));
    }
  } else {
    print(errorPen("Invalid input, try again."));
  }
}

// Remove Member from Committee
void removeMember() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();
  stdout.write("Enter Member ID: ");
  String? memberId = stdin.readLineSync();

  if (committees.containsKey(committeeId) && memberId != null) {
    committees[committeeId]!['members'].remove(memberId);
    logAction(
        'Remove Member', 'Committee ID: $committeeId, Member ID: $memberId');
    print(successPen("Member removed from committee."));
  } else {
    print(errorPen("Invalid Committee ID or Member ID."));
  }
}

// Update Member Details
// Update Member Details
void updateMember() {
  stdout.write("Enter Member ID: ");
  String? memberId = stdin.readLineSync();

  if (users.containsKey(memberId)) {
    stdout.write("Enter New Name (leave blank to keep current): ");
    String? newName = stdin.readLineSync();
    stdout.write("Enter New Phone Number (leave blank to keep current): ");
    String? newPhone = stdin.readLineSync();
    stdout.write("Enter New Email (leave blank to keep current): ");
    String? newEmail = stdin.readLineSync();

    var member = users[memberId]!;
    if (newName != null && newName.isNotEmpty) {
      member['name'] = newName;
    }
    if (newPhone != null && newPhone.isNotEmpty) {
      member['phone'] = newPhone;
    }
    if (newEmail != null && newEmail.isNotEmpty) {
      member['email'] = newEmail;
    }

    logAction('Update Member Details', 'Member ID: $memberId');
    print(successPen("Member details updated successfully."));
  } else {
    print(errorPen("Member ID not found."));
  }
}

// View Committee Members
void viewCommitteeMembers() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();

  if (committees.containsKey(committeeId)) {
    print("\n--- Committee Members ---");
    var members = committees[committeeId]!['members'] as List<dynamic>;
    if (members.isEmpty) {
      print("No members found.");
    } else {
      for (var memberId in members) {
        var member = users[memberId];
        if (member != null) {
          print("Member ID: $memberId");
          print("Name: ${member['name']}");
          print("Phone: ${member['phone']}");
          print("Email: ${member['email']}");
          print("");
        }
      }
    }
    logAction('View Committee Members', 'Committee ID: $committeeId');
  } else {
    print(errorPen("Committee ID not found."));
  }
}

// Select Committee Member
// Select Committee Member
void selectCommitteeMember() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();
  stdout.write("Enter Member ID: ");
  String? memberId = stdin.readLineSync();

  if (committees.containsKey(committeeId) &&
      memberId != null &&
      users.containsKey(memberId)) {
    committees[committeeId]!['roles'][memberId] =
        'Member'; // Example role assignment
    logAction('Select Committee Member',
        'Committee ID: $committeeId, Member ID: $memberId');

    // Notify member via email and SMS
    String memberEmail = users[memberId]!['email'];
    String memberPhone = users[memberId]!['phone'];
    String message =
        "You have been selected for the committee: ${committees[committeeId]!['name']}.";

    sendEmail(memberEmail, message);
   sendSms(memberPhone, message);


    print(successPen("Member selected and notified via email and SMS."));
  } else {
    print(errorPen("Invalid Committee ID or Member ID."));
  }
}

// Modify Committee Requirements
void modifyCommitteeRequirements() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();

  if (committees.containsKey(committeeId)) {
    stdout.write("Enter New Required Number of Members: ");
    String? requiredMembers = stdin.readLineSync();

    if (requiredMembers != null) {
      committees[committeeId]!['requiredMembers'] = int.parse(requiredMembers);
      logAction('Modify Committee Requirements', 'Committee ID: $committeeId');
      print(successPen("Committee requirements updated."));
    } else {
      print(errorPen("Invalid input."));
    }
  } else {
    print(errorPen("Committee ID not found."));
  }
}

// Merge Committees
void mergeCommittees() {
  stdout.write("Enter First Committee ID: ");
  String? firstCommitteeId = stdin.readLineSync();
  stdout.write("Enter Second Committee ID: ");
  String? secondCommitteeId = stdin.readLineSync();

  if (committees.containsKey(firstCommitteeId) &&
      committees.containsKey(secondCommitteeId)) {
    var firstCommittee = committees[firstCommitteeId]!;
    var secondCommittee = committees[secondCommitteeId]!;

    firstCommittee['members'].addAll(secondCommittee['members']);
    firstCommittee['roles'].addAll(secondCommittee['roles']);
    firstCommittee['waitingList'].addAll(secondCommittee['waitingList']);
    firstCommittee['totalMoneyManaged'] += secondCommittee['totalMoneyManaged'];
    firstCommittee['memberParticipation'] =
        ((firstCommittee['memberParticipation'] +
                    secondCommittee['memberParticipation']) /
                2)
            .toInt();

    committees.remove(secondCommitteeId);
    logAction('Merge Committees',
        'Merged Committee IDs: $firstCommitteeId and $secondCommitteeId');
    print(successPen("Committees merged successfully."));
  } else {
    print(errorPen("Invalid Committee IDs."));
  }
}

// Split Committee
void splitCommittee() {
  stdout.write("Enter Committee ID to Split: ");
  String? committeeId = stdin.readLineSync();
  stdout.write("Enter New Committee Name: ");
  String? newName = stdin.readLineSync();

  if (committees.containsKey(committeeId) && newName != null) {
    var originalCommittee = committees[committeeId]!;
    var newId = Random().nextInt(10000).toString();

    committees[newId] = {
      'name': newName,
      'price': originalCommittee['price'],
      'requiredMembers':
          originalCommittee['requiredMembers'] ~/ 2, // Example split
      'members': originalCommittee['members']
          .sublist(0, originalCommittee['requiredMembers'] ~/ 2),
      'roles': {},
      'waitingList': [],
      'scheduledDate': originalCommittee['scheduledDate'],
      'lastRotation': originalCommittee['lastRotation'],
      'rotationInterval': originalCommittee['rotationInterval'],
      'creationDate': formatDate(DateTime.now()),
      'totalMoneyManaged': originalCommittee['totalMoneyManaged'] / 2,
      'memberParticipation': originalCommittee['memberParticipation'] ~/ 2,
      'timeToFill': originalCommittee['timeToFill'] ~/ 2
    };

    originalCommittee['members'] = originalCommittee['members']
        .sublist(originalCommittee['requiredMembers'] ~/ 2);
    originalCommittee['totalMoneyManaged'] /= 2;
    originalCommittee['memberParticipation'] ~/= 2;
    originalCommittee['timeToFill'] ~/= 2;

    logAction('Split Committee',
        'Original Committee ID: $committeeId, New Committee ID: $newId');
    print(successPen("Committee split successfully. New Committee ID: $newId"));
  } else {
    print(errorPen("Invalid Committee ID or input."));
  }
}

// Set Reminders
void setReminders() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();
  stdout.write("Enter Reminder Message: ");
  String? message = stdin.readLineSync();

  if (committees.containsKey(committeeId) && message != null) {
    // In a real implementation, you might schedule notifications
    print(infoPen("Reminder set for Committee ID: $committeeId"));
    sendEmail(users[committeeId]!['email']!, message);
sendSms(users[committeeId]!['phone']!, message);

    logAction('Set Reminder', 'Committee ID: $committeeId, Message: $message');
  } else {
    print(errorPen("Invalid Committee ID or message."));
  }
}

// Rotate Committees
void rotateCommittees() {
  stdout.write("Enter Committee ID: ");
  String? committeeId = stdin.readLineSync();

  if (committees.containsKey(committeeId)) {
    var committee = committees[committeeId]!;
    var currentDate = DateTime.now();
    var lastRotation = DateTime.parse(committee['lastRotation']);
    var interval = committee['rotationInterval'] as int;

    if (currentDate.difference(lastRotation).inDays >= interval) {
      committee['members'] = [];
      committee['waitingList'] = [];
      committee['lastRotation'] = formatDate(currentDate);
      logAction('Rotate Committees', 'Committee ID: $committeeId');
      print(successPen("Committee rotated successfully."));
    } else {
      print(infoPen("Rotation not due yet."));
    }
  } else {
    print(errorPen("Committee ID not found."));
  }
}

// View Statistics
void viewStatistics() {
  print("\n--- Committee Statistics ---");
  for (var entry in committees.entries) {
    var id = entry.key;
    var committee = entry.value;
    print("Committee ID: $id");
    print("Total Money Managed: ${committee['totalMoneyManaged']}");
    print("Average Time to Fill: ${committee['timeToFill']} days");
    print("Member Participation Rate: ${committee['memberParticipation']}%");
    print("");
  }
  logAction('View Statistics', 'Viewed statistics.');
}

// View Committee Popularity Insights
void viewPopularityInsights() {
  print("\n--- Committee Popularity Insights ---");
  for (var entry in committees.entries) {
    var id = entry.key;
    var committee = entry.value;
    print("Committee ID: $id");
    print("Name: ${committee['name']}");
    print("Total Money Managed: ${committee['totalMoneyManaged']}");
    print("Number of Members: ${committee['members'].length}");
    print("");
  }
  logAction('View Popularity Insights', 'Viewed popularity insights.');
}

void processWaitingList(String committeeId) {
  var committee = committees[committeeId];
  var members = committee['members'];
  var requiredMembers = committee['requiredMembers'];
  var waitingList = committee['waitingList'];

  while (members.length < requiredMembers && waitingList.isNotEmpty) {
    var nextMember =
        waitingList.removeAt(0); // Get the first member in the waiting list
    members.add(nextMember['id']);
    committees[committeeId]!['roles'][nextMember['id']] =
        nextMember['role']; // Assign role

    users[nextMember['id']] = {
      'name': nextMember['name'],
      'phone': nextMember['phone'],
      'email': nextMember['email'],
    };

    logAction('Add From Waiting List',
        'Committee ID: $committeeId, Member ID: ${nextMember['id']}');
    print(successPen(
        "Member added from waiting list with role: ${nextMember['role']}."));
  }
}

<%@ page import="java.sql.*, java.util.*, java.security.MessageDigest" %>

<%! 
String hashPassword(String pass){
    try {
        java.security.MessageDigest md = java.security.MessageDigest.getInstance("SHA-256");
        byte[] hash = md.digest(pass.getBytes("UTF-8"));
        StringBuilder hex = new StringBuilder();
        for(byte b : hash){
            hex.append(String.format("%02x",b));
        }
        return hex.toString();
    } catch(Exception e) {
        return pass;
    }
}
%>

<%
HttpSession sessionObj = request.getSession(false);

if (sessionObj == null || sessionObj.getAttribute("username") == null) {
    response.sendRedirect("login.jsp");
    return;
}

String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

String action = request.getParameter("action");
String username = request.getParameter("username");
String fname = request.getParameter("fname");
String lname = request.getParameter("lname");
String password = request.getParameter("password");
String confirmPassword = request.getParameter("confirmPassword");
String role = request.getParameter("role");
String message = "";

if(username==null) username="";
if(fname==null) fname="";
if(lname==null) lname="";
if(role==null) role="User";

List<Map<String,Object>> userList = new ArrayList<>();

try {
    Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
    Connection conn = DriverManager.getConnection(connStr);

    if ("load".equals(action)) {
        if (!username.trim().isEmpty()) {
            PreparedStatement ps = conn.prepareStatement(
                "SELECT uc.FirstName, uc.LastName, u.Password, u.Role " +
                "FROM Users u LEFT JOIN UserCreate uc ON u.UserID=uc.UserID WHERE u.UserName = ?"
            );
            ps.setString(1, username);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                fname = rs.getString("FirstName");
                lname = rs.getString("LastName");
                password = rs.getString("Password"); 
                role = rs.getString("Role");
            } else {
                message = "User not found.";
            }
            rs.close();
            ps.close();
        }
    }
    else if ("save".equals(action)) {
        if (password != null && !password.isEmpty() && !password.equals(confirmPassword)) {
            message = "Passwords do not match!";
        } else {
            PreparedStatement check = conn.prepareStatement("SELECT UserID FROM Users WHERE UserName=?");
            check.setString(1, username);
            ResultSet rsCheck = check.executeQuery();

            boolean exists = false;
            int existingId = -1;

            if (rsCheck.next()) {
                exists = true;
                existingId = rsCheck.getInt("UserID");
            }
            rsCheck.close(); 
            check.close();

            if (exists) {
               
                if (password != null && !password.isEmpty()) {
                    PreparedStatement upUsers = conn.prepareStatement("UPDATE Users SET Password=?, Role=? WHERE UserID=?");
                    upUsers.setString(1, password);
                    upUsers.setString(2, role);
                    upUsers.setInt(3, existingId);
                    upUsers.executeUpdate();
                    upUsers.close();
                } else {
                    PreparedStatement upUsers = conn.prepareStatement("UPDATE Users SET Role=? WHERE UserID=?");
                    upUsers.setString(1, role);
                    upUsers.setInt(2, existingId);
                    upUsers.executeUpdate();
                    upUsers.close();
                }

                PreparedStatement upCreate = conn.prepareStatement("UPDATE UserCreate SET FirstName=?, LastName=? WHERE UserID=?");
                upCreate.setString(1, fname);
                upCreate.setString(2, lname);
                upCreate.setInt(3, existingId);
                upCreate.executeUpdate();
                upCreate.close();
                message = "User updated successfully!";
            } 
            else {
                
                PreparedStatement insUsers = conn.prepareStatement("INSERT INTO Users (UserName, Password, Role) VALUES (?, ?, ?)", Statement.RETURN_GENERATED_KEYS);
                insUsers.setString(1, username);
                insUsers.setString(2, password);
                insUsers.setString(3, role);
                insUsers.executeUpdate();

                ResultSet keys = insUsers.getGeneratedKeys();
                if (keys.next()) {
                    int newId = keys.getInt(1);
                    PreparedStatement insCreate = conn.prepareStatement("INSERT INTO UserCreate (UserID, FirstName, LastName) VALUES (?, ?, ?)");
                    insCreate.setInt(1, newId);
                    insCreate.setString(2, fname);
                    insCreate.setString(3, lname);
                    insCreate.executeUpdate();
                    insCreate.close();
                }
                keys.close();
                insUsers.close();
                message = "User saved successfully!";
            }
            
            username=""; fname=""; lname=""; password=""; confirmPassword=""; role="User";
        }
    }

    else if ("delete".equals(action)) {
        String loggedInUser = (String) sessionObj.getAttribute("username");
        if (username.equals(loggedInUser)) {
            message = "Error: You cannot delete your own account!";
        } else {
            PreparedStatement getId = conn.prepareStatement("SELECT UserID FROM Users WHERE UserName=?");
            getId.setString(1, username);
            ResultSet rsId = getId.executeQuery();
            if (rsId.next()) {
                int delId = rsId.getInt("UserID");
                PreparedStatement d1 = conn.prepareStatement("DELETE FROM UserCreate WHERE UserID=?");
                d1.setInt(1, delId); d1.executeUpdate();
                PreparedStatement d2 = conn.prepareStatement("DELETE FROM Users WHERE UserID=?");
                d2.setInt(1, delId); d2.executeUpdate();
                message = "User deleted successfully!";
                username=""; fname=""; lname="";
            }
        }
    }

    PreparedStatement psAll = conn.prepareStatement("SELECT u.UserName, u.Role, uc.FirstName, uc.LastName FROM Users u LEFT JOIN UserCreate uc ON u.UserID=uc.UserID");
    ResultSet rsAll = psAll.executeQuery();
    while (rsAll.next()) {
        Map<String, Object> row = new HashMap<>();
        row.put("username", rsAll.getString("UserName"));
        row.put("fname", rsAll.getString("FirstName") != null ? rsAll.getString("FirstName") : "");
        row.put("lname", rsAll.getString("LastName") != null ? rsAll.getString("LastName") : "");
        row.put("role", rsAll.getString("Role"));
        userList.add(row);
    }
    conn.close();
} catch (Exception e) {
    message = "Error: " + e.getMessage();
}
%>

<!DOCTYPE html>
<html>
<head>
    <title>User Credentials</title>
    <link rel="stylesheet" href="UserCred.css">
</head>
<body>
    <header>
        <ul class="navigation"> <li><a href="MPOS.jsp">Dashboard</a></li>
            <li><a href="logout.jsp?from=User Credential">Sign Out</a></li>
        </ul>
    </header>

    <div class="user-container">
        <h2>User Credentials</h2>

        <% if(!message.isEmpty()) { %>
        <p style="color: <%= message.contains("Error") ? "red" : "green" %>; text-align:center; font-weight:bold;">
            <%= message %>
        </p>
        
        <% } %>
    
        <form method="post">
            <div class="form-group"> <label>User Name</label>
                <input type="text" name="username" class="input" value="<%=username%>" required>
            </div>

            <div class="form-group">
                <label>First Name</label>
                <input type="text" name="fname" class="input" value="<%=fname%>" required>
            </div>

            <div class="form-group">
                <label>Last Name</label>
                <input type="text" name="lname" class="input" value="<%=lname%>" required>
            </div>

            <div class="form-group">
                <label>Password</label>
                <input type="password" name="password" class="input" value="<%= (action != null && action.equals("load")) ? password : "" %>">
            </div>

            <div class="form-group">
                <label>Confirm Password</label>
                <input type="password" name="confirmPassword" class="input">
            </div>

            <div class="form-group">
                <label>User Type</label>
                <select name="role" class="input" style="height: 40px;"> <option value="User" <%=role.equals("User")?"selected":""%>>User</option>
                    <option value="Admin" <%=role.equals("Admin")?"selected":""%>>Admin</option>
                </select>
            </div>

            <div class="btn-row"> 
                <button type="submit" name="action" value="save" class="btnsubmit">Save</button>
                <button type="submit" name="action" value="delete" class="btnsubmit danger" onclick="return confirmDelete()">Delete</button>
            </div>
        </form>

        <div class="table-container">
    <h3>System Users</h3>
    <table class="user-table">
        <thead>
            <tr>
                <th>Username</th>
                <th>Full Name</th>
                <th>Access Level</th>
                <th style="text-align:center;">Action</th>
            </tr>
        </thead>
        <tbody>
            <% for(Map<String,Object> u : userList) { 
                String userRole = (String)u.get("role");
                String rowClass = "Admin".equalsIgnoreCase(userRole) ? "role-admin" : "role-user";
                String badgeClass = "Admin".equalsIgnoreCase(userRole) ? "badge-admin" : "badge-user";
            %>
            <tr class="<%= rowClass %>">
                <td><strong><%= u.get("username") %></strong></td>
                <td><%= u.get("fname") %> <%= u.get("lname") %></td>
                <td>
                    <span class="<%= badgeClass %>"><%= userRole %></span>
                </td>
                <td style="text-align:center;">
                    <form method="post" style="margin:0;">
                        <input type="hidden" name="username" value="<%= u.get("username") %>">
                        <button name="action" value="load" class="edit-btn">Edit User</button>
                    </form>
                </td>
            </tr>
            <% } %>
        </tbody>
    </table>
</div>

    <script>
    function confirmDelete() {
        var user = document.getElementsByName("username")[0].value;
        if (!user) { 
            alert("Please load a user first."); 
            return false; 
        }
        return confirm("Are you absolutely sure you want to delete user: " + user + "? This cannot be undone.");
    }
    </script>
</body>
</html>
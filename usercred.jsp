<%@ page import="java.sql.*, java.util.*, java.security.MessageDigest" %>
<%@ include file="config.jsp" %>
<%

    if (sessionObj == null || sessionObj.getAttribute("username") == null) {
        response.sendRedirect("login.jsp");
        return;
    }


    String action = request.getParameter("action");
    String username = request.getParameter("username") != null ? request.getParameter("username") : "";
    String fname = request.getParameter("fname") != null ? request.getParameter("fname") : "";
    String lname = request.getParameter("lname") != null ? request.getParameter("lname") : "";
    String password = request.getParameter("password");
    String confirmPassword = request.getParameter("confirmPassword");
    String role = request.getParameter("role") != null ? request.getParameter("role") : "User";
    String message = "";

    List<Map<String,Object>> userList = new ArrayList<>();

    try {
        if ("load".equals(action) && !username.isEmpty()) {
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
            }
        }
        
        //Save
        else if ("save".equals(action)) {
            if (password != null && !password.isEmpty() && !password.equals(confirmPassword)) {
                message = "Error: Passwords do not match!";
            } else {
                PreparedStatement check = conn.prepareStatement("SELECT UserID FROM Users WHERE UserName=?");
                check.setString(1, username);
                ResultSet rsCheck = check.executeQuery();

                if (rsCheck.next()) {
                    int existingId = rsCheck.getInt("UserID");
                    //Update
                    if (password != null && !password.isEmpty()) {
                        PreparedStatement up = conn.prepareStatement("UPDATE Users SET Password=?, Role=? WHERE UserID=?");
                        up.setString(1, password); 
                        up.setString(2, role);
                        up.setInt(3, existingId);
                        up.executeUpdate();
                    } else {
                        PreparedStatement up = conn.prepareStatement("UPDATE Users SET Role=? WHERE UserID=?");
                        up.setString(1, role);
                        up.setInt(2, existingId);
                        up.executeUpdate();
                    }
                    PreparedStatement upInfo = conn.prepareStatement("UPDATE UserCreate SET FirstName=?, LastName=? WHERE UserID=?");
                    upInfo.setString(1, fname);
                    upInfo.setString(2, lname);
                    upInfo.setInt(3, existingId);
                    upInfo.executeUpdate();
                    message = "User updated successfully!";
                } else {

                    PreparedStatement ins = conn.prepareStatement("INSERT INTO Users (UserName, Password, Role) VALUES (?, ?, ?)", Statement.RETURN_GENERATED_KEYS);
                    ins.setString(1, username);
                    ins.setString(2, password); 
                    ins.setString(3, role);
                    ins.executeUpdate();

                    ResultSet keys = ins.getGeneratedKeys();
                    if (keys.next()) {
                        PreparedStatement insInfo = conn.prepareStatement("INSERT INTO UserCreate (UserID, FirstName, LastName) VALUES (?, ?, ?)");
                        insInfo.setInt(1, keys.getInt(1));
                        insInfo.setString(2, fname);
                        insInfo.setString(3, lname);
                        insInfo.executeUpdate();
                    }
                    message = "User created successfully!";
                }
                username=""; fname=""; lname=""; password=""; confirmPassword=""; role="User";
            }
        }

        //Delete
        else if ("delete".equals(action)) {
            if (username.equals(session.getAttribute("username"))) {
                message = "Error: You cannot delete your own account!";
            } else {
                PreparedStatement del1 = conn.prepareStatement("DELETE FROM UserCreate WHERE UserID = (SELECT UserID FROM Users WHERE UserName=?)");
                del1.setString(1, username);
                del1.executeUpdate();
                PreparedStatement del2 = conn.prepareStatement("DELETE FROM Users WHERE UserName=?");
                del2.setString(1, username);
                del2.executeUpdate();
                message = "User deleted.";
                username=""; fname=""; lname="";
            }
        }

        ResultSet rsAll = conn.createStatement().executeQuery(
            "SELECT u.UserName, u.Role, uc.FirstName, uc.LastName FROM Users u " +
            "LEFT JOIN UserCreate uc ON u.UserID=uc.UserID"
        );
        while (rsAll.next()) {
            Map<String, Object> row = new HashMap<>();
            row.put("username", rsAll.getString("UserName"));
            row.put("fname", rsAll.getString("FirstName") != null ? rsAll.getString("FirstName") : "");
            row.put("lname", rsAll.getString("LastName") != null ? rsAll.getString("LastName") : "");
            row.put("role", rsAll.getString("Role"));
            userList.add(row);
        }

    } catch (Exception e) {
        message = "Error: " + e.getMessage();
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>User Management</title>
    <link rel="stylesheet" href="UserCred.css">
</head>
<body>
    <header>
        <ul class="navigation">
            <li><a href="MPOS.jsp">Dashboard</a></li>
            <li><a href="useractivity.jsp">Audit Logs</a></li>
            <li><a href="logout.jsp">Sign Out</a></li>
        </ul>
    </header>

    <div class="user-container">
        <h2>User Credentials</h2>

        <% if(!message.isEmpty()) { %>
            <div style="padding:10px; margin-bottom:15px; border-radius:4px; text-align:center; 
                 background: <%= message.contains("Error") ? "#fee2e2":"#dcfce7"%>; 
                 color: <%= message.contains("Error") ? "#b91c1c":"#15803d"%>;">
                <%= message %>
            </div>
        <% } %>
    
        <form method="post">
            <div class="form-group">
                <label>User Name</label>
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
                <select name="role" class="input" style="height: 40px;">
                    <option value="User" <%=role.equals("User")?"selected":""%>>User</option>
                    <option value="Admin" <%=role.equals("Admin")?"selected":""%>>Admin</option>
                </select>
            </div>

            <div class="btn-row"> 
                <button type="submit" name="action" value="save" class="btnsubmit">Save</button>
                <button type="submit" name="action" value="delete" class="btnsubmit danger" onclick="return confirm('Are you sure?')">Delete</button>
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
                    <% for(Map<String,Object> u : userList) { %>
                    <tr>
                        <td><strong><%= u.get("username") %></strong></td>
                        <td><%= u.get("fname") %> <%= u.get("lname") %></td>
                        <td><%= u.get("role") %></td>
                        <td style="text-align:center;">
                            <form method="post" style="margin:0;">
                                <input type="hidden" name="username" value="<%= u.get("username") %>">
                                <button name="action" value="load" class="edit-btn">Edit</button>
                            </form>
                        </td>
                    </tr>
                    <% } %>
                </tbody>
            </table>
        </div>
    </div>
</body>
</html>
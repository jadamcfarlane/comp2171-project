<%@ page import="java.sql.*, java.util.*, javax.servlet.*, javax.servlet.http.*" %>
<%@ include file="config.jsp" %>

<%
    String username = request.getParameter("username");
    String password = request.getParameter("password");
    String ipAddress = request.getRemoteAddr();

    if(username != null && password != null) {
        try {

            String authSql = "SELECT UserID, Role FROM Users WHERE username=? AND password=?";
            
            try (PreparedStatement ps = conn.prepareStatement(authSql)) {
                ps.setString(1, username);
                ps.setString(2, password);
                
                try (ResultSet rs = ps.executeQuery()) {
                    if(rs.next()) {
                        String role = rs.getString("Role");
                        int uId = rs.getInt("UserID");

                        session.setAttribute("username", username);
                        session.setAttribute("role", role);
                        session.setAttribute("userId", uId);

                        String logSql = "INSERT INTO UserLoginActivity (UserID, UserName, ActivityType, ActivityDescription, IPAddress) VALUES (?, ?, ?, ?, ?)";
                        try (PreparedStatement logPs = conn.prepareStatement(logSql)) {
                            logPs.setInt(1, uId);
                            logPs.setString(2, username);
                            logPs.setString(3, "LOGIN");
                            logPs.setString(4, "User successfully authenticated."); 
                            logPs.setString(5, ipAddress);
                            logPs.executeUpdate();
                        }

                        if(role.equalsIgnoreCase("admin")) {
                            response.sendRedirect("MPOS.jsp");
                        } else {
                            response.sendRedirect("UPOS.jsp");
                        }
                        return; 

                    } else {
                        String failedSql = "INSERT INTO UserLoginActivity (UserName, ActivityType, ActivityTime, IPAddress) VALUES (?, ?, GETDATE(), ?)";
                        try (PreparedStatement failedPs = conn.prepareStatement(failedSql)) {
                            failedPs.setString(1, username);
                            failedPs.setString(2, "FAILED_LOGIN");
                            failedPs.setString(3, ipAddress);
                            failedPs.executeUpdate();
                        }
                        request.setAttribute("error", "Invalid username or password");
                    }
                }
            }
        } catch(Exception e) {
            request.setAttribute("error", "System Error: " + e.getMessage());
        }
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>LOGIN</title>
    <link href="LoginPage.css" rel="stylesheet" />
</head>
<body>

<div class="login-container">
    <header>
        <img src="logo.jpg" style="height: 194px; width: 285px" /><br><br>
    </header>

    <div class="loginbox">
        <h1>MSOL JAMAICA LTD</h1>
        <h3>AQUASOL</h3>
        <h2>Login Here</h2>

        <form method="post">
            <label class="lblemail">Username</label>
            <input type="text" name="username" class="txtemail"
                   placeholder="Please enter your username."
                   required autofocus />

            <label class="lblpassword">Password</label>
            <input type="password" name="password" class="txtpassword"
                   placeholder="Please enter your password."
                   required />

            <button type="submit" class="btnsubmit">LOGIN</button>
        </form>

        <p style="color:red; text-align:center;">
            <%= request.getAttribute("error") != null ? request.getAttribute("error") : "" %>
        </p>
    </div>
</div>

</body>
</html>
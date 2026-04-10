<%@ page import="java.sql.*, java.util.*, javax.servlet.*, javax.servlet.http.*" %>

<%
String username = request.getParameter("username");
String password = request.getParameter("password");
String ipAddress = request.getRemoteAddr();

String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";

if(username != null && password != null){

    try{

        Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");

        Connection conn = DriverManager.getConnection(connStr);

        String sql = "SELECT UserID, Role FROM Users WHERE username=? AND password=?";
        PreparedStatement ps = conn.prepareStatement(sql);

        ps.setString(1, username);
        ps.setString(2, password);

        ResultSet rs = ps.executeQuery();

        if(rs.next()){

            String role = rs.getString("Role");
            int uId = rs.getInt("UserID");

            session.setAttribute("username", username);
            session.setAttribute("role", role);
            session.setAttribute("userId", uId);

            String loginSQL = "INSERT INTO UserLoginActivity (UserID, UserName, ActivityType, ActivityDescription, IPAddress) VALUES (?, ?, ?, ?, ?)";
            PreparedStatement loginPs = conn.prepareStatement(loginSQL);
            loginPs.setInt(1, uId);
            loginPs.setString(2, username);
            loginPs.setString(3, "LOGIN");
            loginPs.setString(4, "User successfully authenticated."); 
            loginPs.setString(5, ipAddress);
            loginPs.executeUpdate();

            if(role.equalsIgnoreCase("admin")){
                response.sendRedirect("MPOS.jsp");
            } else {
                response.sendRedirect("UPOS.jsp");
            }
            conn.close();
            return;

        }else{

            String failedLoginSQL = "INSERT INTO UserLoginActivity (UserName, ActivityType, ActivityTime, IPAddress) VALUES (?, ?, GETDATE(), ?)";
            PreparedStatement failedPs = conn.prepareStatement(failedLoginSQL);
            failedPs.setString(1, username);
            failedPs.setString(2, "FAILED_LOGIN");
            failedPs.setString(3, ipAddress);
            failedPs.executeUpdate();

            request.setAttribute("error","Invalid username or password");
            
        }

        conn.close();

    }catch(Exception e){
        out.println("Database Error: " + e.getMessage());
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
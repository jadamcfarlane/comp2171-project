<%@ page import="java.sql.*, javax.servlet.*, javax.servlet.http.*" %>

<%
    HttpSession sessionObj = request.getSession(false);
    if (sessionObj != null && sessionObj.getAttribute("username") != null) {
        String username = (String) sessionObj.getAttribute("username");

        Object userIdObj = sessionObj.getAttribute("userId");
        int userId = (userIdObj != null) ? (Integer)userIdObj : 0;

        String sourcePage = request.getParameter("from");

        if(sourcePage == null || sourcePage.isEmpty()) {
            String referer = request.getHeader("referer");
            if (referer != null) {
                sourcePage = referer.substring(referer.lastIndexOf("/") + 1);
            } else {
                sourcePage = "Direct Link/Unknown";
            }
        }

        String ipAddress = request.getRemoteAddr();

        String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";
        
        try {
            Class.forName("com.microsoft.sqlserver.jdbc.SQLServerDriver");
            Connection conn = DriverManager.getConnection(connStr);
            
            String sql = "INSERT INTO UserLoginActivity (UserID, UserName, ActivityType, ActivityDescription, ActivityTime, IPAddress) " +
                         "VALUES (?, ?, 'LOGOUT', ?, GETDATE(), ?)";
            
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setInt(1, userId);
            ps.setString(2, username);
            ps.setString(3, "User signed out from: " + sourcePage);
            ps.setString(4, ipAddress);
            ps.executeUpdate();
            
            conn.close();
        } catch (Exception e) {
             e.printStackTrace(); 
        }

        sessionObj.invalidate();
        response.sendRedirect("login.jsp");
        return;
    }
    
%>
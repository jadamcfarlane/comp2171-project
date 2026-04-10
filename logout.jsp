<%@ page import="java.sql.*, javax.servlet.*, javax.servlet.http.*" %>
<%@ page import="java.io.*" %>
<%@ include file="config.jsp" %>

<%

    if (sessionObj != null && sessionObj.getAttribute("username") != null) {
        
        String username = (String) sessionObj.getAttribute("username");
        Object userIdObj = sessionObj.getAttribute("userid"); 
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
        
        try {
            String sql = "INSERT INTO UserLoginActivity (UserID, UserName, ActivityType, ActivityDescription, ActivityTime, IPAddress) " +
                         "VALUES (?, ?, 'LOGOUT', ?, GETDATE(), ?)";
            
            PreparedStatement ps = conn.prepareStatement(sql);
            ps.setInt(1, userId);
            ps.setString(2, username);
            ps.setString(3, "User signed out from: " + sourcePage);
            ps.setString(4, ipAddress);
            ps.executeUpdate();
            
            ps.close();
            if (conn != null) conn.close(); 
            
        } catch (Exception e) {
             e.printStackTrace(); 
        }
        sessionObj.invalidate();
        response.sendRedirect("login.jsp");
        return;
    } else {
        response.sendRedirect("login.jsp");
    }
%>
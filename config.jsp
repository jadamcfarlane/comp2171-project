<%@ page import="java.sql.*, java.util.*, java.io.*" %>
<%
    
    HttpSession sessionObj = request.getSession(false);
    if (sessionObj == null || sessionObj.getAttribute("username") == null) {
        if (!request.getRequestURI().endsWith("login.jsp")) {
            response.sendRedirect("login.jsp");
            return;
        }
    }

    String connStr = "jdbc:sqlserver://DESKTOP-KIRN4D4\\SQLEXPRESS;databaseName=Aquasol;encrypt=false;integratedSecurity=true";
    String driver = "com.microsoft.sqlserver.jdbc.SQLServerDriver";
    
    Connection conn = null;
    try {
        Class.forName(driver);
        conn = DriverManager.getConnection(connStr);
    } catch (Exception e) {
        out.println("Connection Error: " + e.getMessage());
    }
%>
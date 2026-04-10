<%@ page import="java.sql.*, java.io.*" %>
<%@ page import="java.time.*, java.time.format.TextStyle" %>
<%@ page import="java.util.Locale" %>
<%@ page import="java.util.Map" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.HashMap" %>
<%@ include file="config.jsp" %>

<%
    int month;
    String m = request.getParameter("month");
    if (m == null) {
        month = LocalDate.now().getMonthValue();
    } else {
        month = Integer.parseInt(m);
    }

    java.util.List<Map<String,Object>> report = new ArrayList<>();
    double[] monthlyRevenue = new double[12];

    try {
        PreparedStatement ps = conn.prepareStatement(
            "SELECT i.ItemName, i.Stock AS RemainingStock, " +
            "ISNULL(SUM(s.Qty),0) AS TotalSold, " +
            "ISNULL(SUM(s.Total),0) AS Revenue " +
            "FROM Item i " +
            "LEFT JOIN Sales s ON i.ItemID=s.ItemID AND MONTH(s.DateSold)=? " +
            "GROUP BY i.ItemName, i.Stock " +
            "ORDER BY i.ItemName"
        );
        ps.setInt(1, month);
        ResultSet rs = ps.executeQuery();

        while(rs.next()){
            Map<String,Object> row = new HashMap<>();
            row.put("ItemName", rs.getString("ItemName"));
            row.put("RemainingStock", rs.getInt("RemainingStock"));
            row.put("TotalSold", rs.getInt("TotalSold"));
            row.put("Revenue", rs.getDouble("Revenue"));
            report.add(row);
        }

        PreparedStatement psChart = conn.prepareStatement(
            "SELECT MONTH(DateSold) m, SUM(Total) r FROM Sales GROUP BY MONTH(DateSold)"
        );
        ResultSet rc = psChart.executeQuery();
        while(rc.next()){
            int monthIdx = rc.getInt("m") - 1;
            if(monthIdx >= 0 && monthIdx < 12) {
                monthlyRevenue[monthIdx] = rc.getDouble("r");
            }
        }
        
    } catch(Exception e) {
        e.printStackTrace();
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Inventory & Sales Report</title>
    <link href="Report.css" rel="stylesheet">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.9.2/html2pdf.bundle.min.js"></script>
    <style>
        .lowstock {
            background: #ffdddd;
            font-weight: bold;
        }
    </style>
</head>
<body>

<header>
    <ul class="navigation">
        <li><a href="MPOS.jsp">Dashboard</a></li>
        <li><a href="Sales.jsp">Sales</a></li>
        <li><a href="custhistory.jsp?from=MPOS">Customer History</a></li>
        <li><a href="useractivity.jsp">User Activity</a></li>
        <li><a href="logout.jsp?from=Reports">Sign Out</a></li>
    </ul>
</header>

<div class="dashboard" id="reportArea">
    <h1 class="dashboard-title">Inventory & Sales Report</h1>

    <form method="get" action="Report.jsp">
        <label>Month:</label>
        <select name="month" onchange="this.form.submit()">
            <%
            for(int i=1; i<=12; i++){
                String name = Month.of(i).getDisplayName(TextStyle.FULL, Locale.ENGLISH);
            %>
            <option value="<%=i%>" <%= (i==month?"selected":"") %> >
                <%=name%>
            </option>
            <% } %>
        </select>
    </form>

    <br>
    <h2>Monthly Revenue</h2>
    <div style="max-height: 400px;">
        <canvas id="salesChart"></canvas>
    </div>

    <br>
    <table class="report-table">
        <thead>
            <tr>
                <th>Item Name</th>
                <th>Remaining Stock</th>
                <th>Total Sold</th>
                <th>Revenue ($)</th>
            </tr>
        </thead>
        <tbody>
            <%
            for(Map<String,Object> row : report){
                int stock = (Integer)row.get("RemainingStock");
            %>
            <tr class="<%= (stock <= 5 ? "lowstock" : "") %>">
                <td><%=row.get("ItemName")%></td>
                <td><%=row.get("RemainingStock")%></td>
                <td><%=row.get("TotalSold")%></td>
                <td>$<%=String.format("%.2f", (Double)row.get("Revenue"))%></td>
            </tr>
            <% } %>
        </tbody>
    </table>

    <br>
    <button onclick="window.print()" class="print-btn">Print Report</button>
    <button onclick="downloadPDF()" class="print-btn">Download PDF</button>
</div>

<script>
    var revenueData = [
        <%
        for(int i=0; i<12; i++){
            out.print(monthlyRevenue[i]);
            if(i < 11) out.print(",");
        }
        %>
    ];

    new Chart(document.getElementById("salesChart"), {
        type: "line",
        data: {
            labels: ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"],
            datasets: [{
                label: "Revenue ($)",
                data: revenueData,
                borderColor: "#3498db",
                backgroundColor: "rgba(52, 152, 219, 0.2)",
                fill: true,
                borderWidth: 2,
                tension: 0.1
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false
        }
    });

    function downloadPDF(){
        var element = document.getElementById("reportArea");
        var opt = {
            margin:       0.5,
            filename:     'Inventory_Sales_Report.pdf',
            image:        { type: 'jpeg', quality: 0.98 },
            html2canvas:  { scale: 2 },
            jsPDF:        { unit: 'in', format: 'letter', orientation: 'portrait' }
        };
        html2pdf().set(opt).from(element).save();
    }
</script>

</body>
</html>
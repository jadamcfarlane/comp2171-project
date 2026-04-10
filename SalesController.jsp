<%@ page import="java.util.Map" %>
<%@ page import="java.util.ArrayList" %>
<%@ page import="java.util.HashMap" %>
<%@ page import="java.sql.*,java.io.*" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="com.itextpdf.text.*" %>
<%@ page import="com.itextpdf.text.pdf.*" %>
<%@ include file="config.jsp" %>

<%
    String action = request.getParameter("action");
    String source = request.getParameter("source"); 
    
    
    java.util.List<Map<String,Object>> cart = (java.util.List<Map<String,Object>>) session.getAttribute("cart");
    if (cart == null) {
        cart = new ArrayList<>();
        session.setAttribute("cart", cart);
    }

    try {
        // SEARCH 
        if ("search".equals(action)) {
            String search = request.getParameter("search");
            PreparedStatement ps = conn.prepareStatement("SELECT ItemID, ItemName, Price FROM Item WHERE ItemName LIKE ?");
            ps.setString(1, "%" + search + "%");
            ResultSet rs = ps.executeQuery();
            
            java.util.List<Map<String,Object>> items = new ArrayList<>();
            while(rs.next()){
                Map<String,Object> item = new HashMap<>();
                item.put("id", rs.getInt("ItemID"));
                item.put("name", rs.getString("ItemName"));
                item.put("price", rs.getDouble("Price"));
                items.add(item);
            }
            request.setAttribute("searchResults", items);
            request.getRequestDispatcher(source + ".jsp").forward(request, response);
            return;
        }

        // ADD TO CART
        if ("add".equals(action)) {
            int id = Integer.parseInt(request.getParameter("id"));
            PreparedStatement ps = conn.prepareStatement("SELECT ItemName, Price, Stock FROM Item WHERE ItemID=?");
            ps.setInt(1, id);
            ResultSet rs = ps.executeQuery();
            if(rs.next()){
                int stock = rs.getInt("Stock");
                boolean found = false;
                for(Map<String,Object> item : cart){
                    if((int)item.get("id") == id){
                        if((int)item.get("qty") + 1 <= stock) {
                            item.put("qty", (int)item.get("qty") + 1);
                        }
                        found = true;
                    }
                }
                if(!found && stock > 0){
                    Map<String,Object> newItem = new HashMap<>();
                    newItem.put("id", id);
                    newItem.put("name", rs.getString("ItemName"));
                    newItem.put("price", rs.getDouble("Price"));
                    newItem.put("qty", 1);
                    cart.add(newItem);
                }
            }
            response.sendRedirect(source + ".jsp");
            return;
        }

        // NEW ORDER / RESET
        if("new".equals(action)) { 
            cart.clear(); 
            session.removeAttribute("showReceipt"); 
            response.sendRedirect(source + ".jsp");
            return;
        }

        // REMOVE ITEM
        if("remove".equals(action)) { 
            int id = Integer.parseInt(request.getParameter("id"));
            cart.removeIf(i -> (int)i.get("id") == id);
            response.sendRedirect(source + ".jsp");
            return;
        }

        if ("checkout".equals(action)) {
            String selectedCustId = request.getParameter("selectedCustomerId");
            int custId = (selectedCustId != null) ? Integer.parseInt(selectedCustId) : 0;

            if (cart.isEmpty()) {
                out.println("<script>alert('Cart is empty'); window.location='"+source+".jsp';</script>");
            } else {
                String paymentMethod = request.getParameter("paymentMethod");
                if (paymentMethod == null) paymentMethod = "Cash";
                
                String cashier = (session.getAttribute("username") != null) ? session.getAttribute("username").toString() : "Unknown";
                String receiptNo = "R" + new SimpleDateFormat("yyyyMMddHHmmss").format(new java.util.Date());
                
                StringBuilder sb = new StringBuilder();
                double subtotal = 0;

                sb.append("<div style='text-align:center;'>");
                sb.append("<img src='" + request.getContextPath() + "/logo.jpg' style='width:120px'><br>");
                sb.append("<h2>MSOL JAMAICA LTD</h2>");
                sb.append("<h4>Red Bank, Red Bank District | 876-291-4000</h4>");
                sb.append("<h4>Receipt No: " + receiptNo + "</h4>");
                sb.append("<p>Date: " + new SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date()) + "</p>");
                sb.append("<p><strong>Cashier:</strong> " + cashier + " | <strong>Payment:</strong> " + paymentMethod + "</p>");
                sb.append("</div><hr/>");

                sb.append("<table style='width:100%; border-collapse:collapse;'>");
                sb.append("<tr><th align='left'>Item</th><th>Qty</th><th>Price</th><th>Total</th></tr>");

                for (Map<String, Object> item : cart) {
                    String name = item.get("name").toString();
                    int itemId = (int) item.get("id");
                    int qty = (int) item.get("qty");
                    double price = ((Number) item.get("price")).doubleValue();
                    double total = qty * price;
                    subtotal += total;

                    sb.append("<tr><td>" + name + "</td><td align='center'>" + qty + "</td><td align='center'>$" + String.format("%.2f", price) + "</td><td align='center'>$" + String.format("%.2f", total) + "</td></tr>");

                    // DB Sales
                    PreparedStatement psSales = conn.prepareStatement("INSERT INTO Sales (ReceiptNo, ItemID, Qty, Price, Total, DateSold, ReceiptHTML, CustomerID) VALUES (?, ?, ?, ?, ?, GETDATE(), '', ?)");
                    psSales.setString(1, receiptNo); psSales.setInt(2, itemId); psSales.setInt(3, qty);
                    psSales.setDouble(4, price); psSales.setDouble(5, total); psSales.setInt(6, custId);
                    psSales.executeUpdate();

                    // DB Update Stock
                    PreparedStatement psUpd = conn.prepareStatement("UPDATE Item SET Stock = Stock - ?, LastSoldQty = ? WHERE ItemID = ? AND Stock >= ?");
                    psUpd.setInt(1, qty); psUpd.setInt(2, qty); psUpd.setInt(3, itemId); psUpd.setInt(4, qty);
                    psUpd.executeUpdate();
                }

                double tax = subtotal * 0.05;
                double grandTotal = subtotal + tax;

                sb.append("</table><hr/>");
                sb.append("<p align='right'>Subtotal: $" + String.format("%.2f", subtotal) + "</p>");
                sb.append("<p align='right'>Tax (5%): $" + String.format("%.2f", tax) + "</p>");
                sb.append("<h3 align='right'>Total: $" + String.format("%.2f", grandTotal) + "</h3>");
                sb.append("<p style='text-align:center;'>Thank you for your purchase!</p>");

                PreparedStatement psFinal = conn.prepareStatement("UPDATE Sales SET ReceiptHTML=? WHERE ReceiptNo=?");
                psFinal.setString(1, sb.toString()); psFinal.setString(2, receiptNo);
                psFinal.executeUpdate();

                session.setAttribute("lastCart", new ArrayList<>(cart));
                session.setAttribute("receiptHTML", sb.toString());
                session.setAttribute("showReceipt", true);
                session.setAttribute("subtotal", subtotal);
                session.setAttribute("tax", tax);
                session.setAttribute("grandTotal", grandTotal);
                
                cart.clear();
                response.sendRedirect(source + ".jsp");
                return;
            }
        }

        if("pdf".equals(action) || "receipt".equals(action)){
            java.util.List<Map<String,Object>> lastCart = (java.util.List<Map<String,Object>>)session.getAttribute("lastCart");
            double sub = (double)session.getAttribute("subtotal");
            double tx = (double)session.getAttribute("tax");
            double gTotal = (double)session.getAttribute("grandTotal");

            response.setContentType("application/pdf");
            response.setHeader("Content-Disposition","attachment; filename=receipt.pdf");

            Document document = new Document();
            PdfWriter.getInstance(document, response.getOutputStream());
            document.open();
            document.add(new Paragraph("MSOL JAMAICA LTD"));
            document.add(new Paragraph("Sales Receipt\n\n"));

            PdfPTable table = new PdfPTable(4);
            table.setWidthPercentage(100);
            table.addCell("Item"); table.addCell("Qty"); table.addCell("Price"); table.addCell("Total");

            for(Map<String,Object> item : lastCart){
                int qty = (int)item.get("qty");
                double price = ((Number)item.get("price")).doubleValue();
                table.addCell(item.get("name").toString());
                table.addCell(String.valueOf(qty));
                table.addCell("$" + String.format("%.2f", price));
                table.addCell("$" + String.format("%.2f", (qty * price)));
            }
            document.add(table);
            document.add(new Paragraph("\nSubtotal: $" + String.format("%.2f", sub)));
            document.add(new Paragraph("Tax (5%): $" + String.format("%.2f", tx)));
            document.add(new Paragraph("Grand Total: $" + String.format("%.2f", gTotal)));
            document.close();
            return; 
        }

    } catch (Exception e) {
        e.printStackTrace();
        out.println("Error: " + e.getMessage());
    }
%>
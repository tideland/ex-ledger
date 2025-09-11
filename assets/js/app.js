// Tideland Ledger - Main JavaScript
// Minimal JS for Phoenix LiveView

// Import Phoenix LiveView JS
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";

// Import Hooks (if any)
// import Hooks from "./hooks";

// Define Hooks (empty for now, will be added as needed)
const Hooks = {};

// Initialize CSRFToken from meta tag
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

// Create LiveSocket with minimal configuration
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});

// Connect LiveSocket
liveSocket.connect();

// Make liveSocket available for debugging in development
window.liveSocket = liveSocket;

// Add keyboard shortcuts as specified in WUI design
document.addEventListener("keydown", (e) => {
  // Only trigger if Alt key is pressed
  if (e.altKey) {
    switch (e.key) {
      case "n": // Alt+N = New Entry
        window.location.href = "/buchungen/neu";
        break;
      case "k": // Alt+K = Accounts
        window.location.href = "/konten";
        break;
      case "b": // Alt+B = Reports
        window.location.href = "/berichte";
        break;
    }
  }
});

// Simple utility functions for the application
window.appUtils = {
  // Format amount with German number formatting
  formatAmount: (amount) => {
    return new Intl.NumberFormat("de-DE", {
      style: "currency",
      currency: "EUR"
    }).format(amount);
  },

  // Format date in German format
  formatDate: (dateString) => {
    const date = new Date(dateString);
    return new Intl.DateTimeFormat("de-DE").format(date);
  }
};

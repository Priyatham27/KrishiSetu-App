# 🌾 KrishiSetu – Direct Bridge Between Farmers & Buyers  
### 🚀 AVISHKAAR National Hackathon – Project Submission  
**Theme:** Agriculture & Food Technology  
**Problem Statement ID:** AVS301  

KrishiSetu is a cross-platform mobile application built to eliminate middlemen and empower farmers with **direct access to buyers**, ensuring fair pricing, transparency, and higher earnings.

---

## 🟩 Key Highlights
- 📱 Mobile-first, user-friendly interface  
- 🔄 Real-time listing, offers & price negotiations  
- 💬 Buyer–Farmer chat for transparent deals  
- 🧾 Order placement & simple transaction flow  
- 🧑‍🌾 Two separate roles → **Farmer** & **Buyer**  
- ☁️ Powered by Firebase backend  

---

# 🧠 Problem Statement  
Many farmers rely on middlemen to sell their produce. They lose a major share of their income and lack a transparent channel to directly connect with buyers.

📌 **Goal:**  
Build a platform that connects farmers directly with buyers/retailers, enabling listing, negotiation, and transaction management.

---

# ✅ Solution – KrishiSetu  
KrishiSetu provides:

### 👨‍🌾 **For Farmers**
- Add produce listings (price, quantity, category, images)
- Manage uploaded produce
- Receive & negotiate buyer offers
- Confirm orders

### 🛒 **For Buyers**
- Browse verified farmer listings
- Apply filters & sort
- Negotiate pricing
- Place orders with COD

---

# 🏗️ Architecture Overview
Flutter UI → Provider State Mgmt → Firebase Auth
→ Firestore DB → Firebase Storage

---

# 🛠️ Tech Stack

### **Frontend (Mobile App)**
- Flutter (Dart)
- Material 3 UI
- Provider (state management)
- HTTP, Dio, Image Picker

### **Backend**
- Firebase Authentication
- Firebase Firestore
- Firebase Storage

### **Tools Used**
- Android Studio
- GitHub
- Figma (UI mockups)
- ChatGPT (Rapid prototyping)
- Canva (Presentations)

---

# 📂 **Project Structure**
lib/
├── screens/
├── models/
├── services/
├── widgets/
└── assets/
├── icons/
└── illustrations/

---

# ▶️ **How to Run the App**

### 1️⃣ Clone the repo
```bash
git clone https://github.com/Priyatham27/KrishiSetu-App.git
cd KrishiSetu-App
flutter pub get
flutter run


🧑‍🤝‍🧑 Team Avengers
| Name                    | Role                        |
| ----------------------- | --------------------------- |
| **Priyatham Kotipalli** | Team Leader, Lead Developer |
| **K. Chaitanya Prasad** | Backend & Testing           |
| **Ch. Ram Charan**      | UI/UX & Documentation       |
| **B. Venkatesh**        | Firebase Integration & QA   |

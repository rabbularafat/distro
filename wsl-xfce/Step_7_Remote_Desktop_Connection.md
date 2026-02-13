# 🖥️ Final Step: Remote Desktop Connection

Once everything is installed and XRDP is running, you can connect to your Linux desktop.

## 🔹 Connection Steps

1. **Get your IP Address** (Inside Debian):
   ```bash
   ip a | grep eth0
   ```
   *Copy the IP address (e.g., 172.xx.xx.xx).*

2. **Open Remote Desktop Connection** (Windows):
   - Press `Win + R`, type `mstsc`, and hit Enter.
   
3. **Connect**:
   - In the **Computer** field, paste your **WSL IP Address**.
   - Click **Connect**.

4. **Login**:
   - Use your **Linux username** and **password** (the ones you created when first launching Debian).

## ⚠️ Important Notes
- **IP Changes:** The WSL IP address may change after a Windows restart or `wsl --shutdown`. Always check it using `ip a`.
- **Performance:** If it feels laggy, reduce the color depth in the MSTSC options (Display tab).

🎉 **You should now see the XFCE desktop!**

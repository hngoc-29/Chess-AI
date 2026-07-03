#!/bin/bash
# Script để debug Android app - xem log chi tiết

echo "=========================================="
echo "King's Gambit AI Android Debug Script"
echo "=========================================="
echo ""

# Kiểm tra adb
if ! command -v adb &> /dev/null; then
    echo "❌ adb không tìm thấy. Cài đặt Android SDK platform-tools"
    exit 1
fi

# Kiểm tra thiết bị
devices=$(adb devices | grep -v "List" | grep "device$")
if [ -z "$devices" ]; then
    echo "❌ Không tìm thấy thiết bị Android"
    echo "Hãy kết nối thiết bị và bật USB debugging"
    exit 1
fi

echo "✅ Thiết bị đã kết nối:"
adb devices
echo ""

# Menu lựa chọn
echo "Chọn hành động:"
echo "1) Xóa log cũ và xem log mới (Real-time)"
echo "2) Xem log đầy đủ"
echo "3) Xem chỉ ERROR và CRASH"
echo "4) Xem log của app King's Gambit AI"
echo "5) Cài đặt và chạy app, sau đó xem log"
echo "6) Gỡ cài đặt app"
echo ""
read -p "Nhập lựa chọn (1-6): " choice

case $choice in
    1)
        echo "🔄 Xóa log cũ..."
        adb logcat -c
        echo "📱 Đang xem log real-time (Ctrl+C để dừng)..."
        echo "➡️  Hãy mở app trên điện thoại ngay bây giờ"
        echo ""
        adb logcat | grep -E "com.kingsgambit.ai|King's Gambit AI|kings_gambit_ai|Flutter|AndroidRuntime|FATAL|ERROR"
        ;;
    2)
        echo "📱 Đang xem log đầy đủ (Ctrl+C để dừng)..."
        adb logcat
        ;;
    3)
        echo "📱 Đang xem ERROR và CRASH (Ctrl+C để dừng)..."
        adb logcat *:E
        ;;
    4)
        echo "📱 Đang xem log của King's Gambit AI (Ctrl+C để dừng)..."
        adb logcat | grep -E "com.kingsgambit.ai|King's Gambit AI|kings_gambit_ai|Flutter"
        ;;
    5)
        echo "🔄 Tìm APK file..."
        APK_FILE=$(find . -name "*.apk" -type f | grep -E "release|app-release" | head -1)

        if [ -z "$APK_FILE" ]; then
            APK_FILE=$(find . -name "*.apk" -type f | head -1)
        fi

        if [ -z "$APK_FILE" ]; then
            echo "❌ Không tìm thấy APK file"
            exit 1
        fi

        echo "📦 APK: $APK_FILE"
        echo "📲 Đang cài đặt..."
        adb install -r "$APK_FILE"

        echo ""
        echo "🔄 Xóa log cũ..."
        adb logcat -c

        echo "🚀 Đang chạy app..."
        adb shell am start -n com.kingsgambit.ai/.MainActivity

        sleep 2
        echo ""
        echo "📱 Log của app:"
        echo "=========================================="
        adb logcat | grep -E "com.kingsgambit.ai|King's Gambit AI|kings_gambit_ai|Flutter|AndroidRuntime|FATAL|ERROR"
        ;;
    6)
        echo "🗑️  Đang gỡ cài đặt app..."
        adb uninstall com.kingsgambit.ai
        echo "✅ Hoàn tất"
        ;;
    *)
        echo "❌ Lựa chọn không hợp lệ"
        exit 1
        ;;
esac

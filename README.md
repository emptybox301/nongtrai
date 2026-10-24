# 🌾 Nông Trại (Roblox)

Game nông trại có pet ngũ hành, hợp thể, nhà triển lãm, cửa hàng hạt giống / pet / dụng cụ. Toàn bộ map và giao diện được tạo bằng code, không cần asset ngoài.

## Cách mở

1. Mở **Roblox Studio** → File → Open from File → chọn `nongtrai.rbxlx`.
2. Bấm **Play** để chơi thử.
3. Muốn lưu dữ liệu: File → Publish to Roblox, rồi vào **Game Settings → Security → bật "Enable Studio Access to API Services"**.
4. Khi publish, vào **Game Settings → Places → Max Players = 5** (map có 5 nông trại; người thứ 6 sẽ bị mời sang server khác).

> Không bật API Services thì game vẫn chơi được, chỉ là không lưu tiến trình.

## Cách chơi

- Mỗi server tối đa **5 người**, mỗi người 1 nông trại gồm 24 ô đất + 4 ao nuôi thủy sản.
- **1 Nhà Triển Lãm chung** ở giữa map, chia 5 khu, mỗi người 1 khu 3 bục.
- Chọn hạt ở thanh dưới màn hình → chạm ô đất để trồng → chạm cây chín để thu hoạch.
- Đi tới các quầy ở đường chính và bấm nút tương tác:
  - 🌱 **Hạt Giống** — 8 loại hạt, nhập hàng mới mỗi 5 phút, hạt hiếm có khi hết.
  - 🛠 **Dụng Cụ** — Mảnh Hợp Thể, Bình Tưới, Phân Bón, Xẻng, Thức Ăn Cá, Bùa May Mắn.
  - 🐾 **Cửa Hàng Pet** — 5 pet cơ bản theo 5 hệ.
  - 🐟 **Thủy Sản** — 6 loại con giống: Cá Rô Phi, Tôm Càng, Cá Chép, Cua, Cá Koi, Cá Rồng Vàng.
  - 💰 **Bán Hàng** — bán nông sản và thủy sản.

### Ao nuôi thủy sản
- Chọn con giống ở thanh dưới → chạm vào ao trống để thả → chờ lớn → chạm để thu hoạch (mỗi ao cho nhiều con).
- **Thức Ăn Cá** (quầy Dụng Cụ): rút 30% thời gian còn lại và +1 con khi thu hoạch, tối đa 3 lần/ao.
- Thủy sản cũng có thể đột biến (Khổng Lồ / Vàng / Cầu Vồng). Xẻng dùng để xả ao.

Nút bên phải màn hình: **Pet** (trang bị tối đa 3, hợp thể), **Túi**, **Triển lãm**, **❓ Hướng dẫn**.

### Hướng dẫn tân thủ
Người chơi mới vào sẽ thấy khung hướng dẫn 9 bước ở góc trái, kèm tia sáng vàng và mũi tên ⬇ chỉ tới đúng chỗ cần đến:
1. Giới thiệu nông trại → 2. Trồng Cà Rốt → 3. Thu hoạch → 4. Bán ở quầy Bán Hàng → 5. Mua thêm hạt →
6. Thả cá xuống ao → 7. Giới thiệu pet ngũ hành & hợp thể → 8. Giới thiệu nhà triển lãm chung → 9. Nhận thưởng.

Các bước hành động tự chuyển khi người chơi làm xong. Hoàn thành được thưởng 200 xu (sửa `Config.TutorialReward`), bấm "Bỏ qua" thì không có thưởng. Tiến độ hướng dẫn được lưu, thoát ra vào lại vẫn tiếp tục đúng bước. Nội dung các bước nằm trong `src/client/Tutorial.lua`.

## Hệ ngũ hành

| Hệ | Pet cơ bản | Buff |
|---|---|---|
| Kim | Hổ Kim | + giá bán nông sản |
| Mộc | Thỏ Lá | + tốc độ lớn của cây |
| Thủy | Rùa Nước | + cơ hội thu hoạch gấp đôi, thủy sản lớn nhanh hơn |
| Hỏa | Cáo Lửa | + may mắn ra nông sản đột biến (Khổng Lồ x2, Vàng x5, Cầu Vồng x15) |
| Thổ | Chuột Đất | + cơ hội hoàn lại hạt giống |

**Hợp thể** (cần Mảnh Hợp Thể):
- 2 pet cùng hệ → lên 1 bậc (Thường → Hiếm → Sử Thi → Huyền Thoại → Thần Thoại).
- 2 pet khác hệ → pet đa hệ, giữ bậc cao nhất, có buff của tất cả các hệ.
- **Tương sinh** (Mộc→Hỏa→Thổ→Kim→Thủy→Mộc): pet mới mạnh thêm 25% ☯.
- **Tương khắc** (Mộc✕Thổ, Thổ✕Thủy, Thủy✕Hỏa, Hỏa✕Kim, Kim✕Mộc): chỉ 70% thành công, thất bại thì mất mảnh nhưng còn pet.
- Gom đủ 5 hệ → **Ngũ Hành Thần Thú**.

**Nhà triển lãm chung**: trưng bày pet, nông sản hoặc thủy sản ở khu của mình → nhận xu mỗi phút. Người chơi khác bấm ❤ ở khu của bạn → bạn nhận thưởng xu.

## Cấu trúc mã

```
src/shared/Config.lua        -- mọi số liệu: giá, thời gian lớn, buff, tỉ lệ đột biến...
src/shared/PetUtil.lua       -- tính buff, xem trước hợp thể (dùng chung server/client)
src/server/Main.server.lua   -- logic game: trồng, thu hoạch, mua bán, pet, triển lãm
src/server/WorldBuilder.lua  -- dựng map bằng code
src/server/Visuals.lua       -- mô hình pet và nông sản
src/server/DataService.lua   -- lưu dữ liệu (DataStore)
src/client/Client.client.lua -- toàn bộ giao diện (hỗ trợ điện thoại)
src/client/Tutorial.lua      -- hướng dẫn tân thủ từng bước
```

Cân bằng game: chỉ cần sửa `Config.lua`.
Dùng Rojo (`rojo serve`) nếu muốn sửa code bằng VS Code và đồng bộ vào Studio.

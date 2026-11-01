# Somwang Bank V1 — คู่มือเริ่มใช้งาน

เว็บแอปภาษาไทยสำหรับบริหารเงินกองกลางครอบครัว รองรับ PC/มือถือ ใช้ Supabase PostgreSQL และ Netlify Functions

## A. สร้าง Supabase
1. ไปที่ https://supabase.com/dashboard > New project
2. ตั้งชื่อ Somwang Bank เลือก region ใกล้ไทย (เช่น Singapore) ตั้ง Database Password ที่ปลอดภัย แล้ว Create project
3. รอจน Project พร้อม จากเมนู SQL Editor > New query เปิดไฟล์ `schema.sql` คัดลอกเนื้อหาทั้งหมดไปวาง แล้ว Run **ครั้งเดียว**
4. ไปที่ Project Settings > API Keys (ชื่อเมนูอาจเปลี่ยน) คัดลอก Project URL และ `service_role` key / secret key ที่ใช้ฝั่งเซิร์ฟเวอร์เท่านั้น
5. **ห้าม** ใส่ secret key ในไฟล์ HTML, JS หรือส่งให้บุคคลอื่น

## B. อัปโหลด Netlify
1. แตกไฟล์ ZIP เป็นโฟลเดอร์ `somwang-bank`
2. แนะนำให้สร้าง GitHub repository แบบ **private** แล้วอัปโหลดไฟล์ทั้งหมด (รวมโฟลเดอร์ `netlify/functions`) จากนั้น Netlify > Add new project > Import an existing project > GitHub > เลือก repository
3. Build command: **เว้นว่าง**; Publish directory: `.`; Functions directory: `netlify/functions` (กำหนดไว้ใน netlify.toml)
4. ใน Netlify > Site configuration / Project configuration > Environment variables เพิ่ม 4 ตัว:
   - `SUPABASE_URL` = Project URL จาก Supabase
   - `SUPABASE_SERVICE_ROLE_KEY` = Secret/service_role key จาก Supabase (ต้องเก็บเป็นความลับ)
   - `APP_PINS` = รหัส PIN สองรหัส คั่นด้วย comma (กำหนดเองใน Netlify)
   - `SESSION_SECRET` = ค่าสุ่มยาวอย่างน้อย 32 ไบต์ เช่น ผลลัพธ์จาก `openssl rand -hex 32` (อย่าใช้ PIN เป็น secret)
5. Deploy site / Trigger deploy หลังเพิ่ม Environment variables แล้ว
6. เปิด URL `.netlify.app` ที่ Netlify สร้างให้ จะเห็นหน้าใส่ PIN ก่อน Dashboard

**สำคัญ:** วิธีลากโฟลเดอร์ไปวางแบบ Netlify Drop จะไม่เหมาะกับโปรเจกต์นี้ เพราะมี Netlify Functions ฝั่งเซิร์ฟเวอร์ ให้ Deploy ผ่าน Git หรือ Netlify CLI แทน

## C. ทดสอบ
1. เข้าด้วย PIN ที่กำหนดไว้
2. เงินเข้า > เลือกกองทุน > บันทึก 1000 บาท
3. เงินยืม > เลือกเงินเก็บทั่วไปหรือค่ารถ > บันทึก 100 บาท พร้อมหมายเหตุ
4. ตรวจสอบ Dashboard: ยอดเงินในธนาคารตามแอปลดลง 100 บาท; ยอดเงินยืมค้างคืนเพิ่ม 100 บาท
5. ส่งคืนเงินยืม 40 บาท: เงินคืนเข้ากองทุนเดิม; ยอดค้างเหลือ 60 บาท
6. ลองกองทุนลูก: จะไม่มีตัวเลือกในเมนูยืม และฐานข้อมูลปฏิเสธการยืมจากกองทุนที่ protected
7. ตรวจสอบยอดธนาคารด้วยยอดจริงที่คุณดูเอง

## ข้อจำกัด V1 และข้อควรระวัง
- ยังไม่ได้เชื่อมต่อกับธนาคารจริง และไม่ใช่แอปธนาคาร
- รหัส PIN สี่หลักเป็นวิธีป้องกันที่ค่อนข้างอ่อน และเวอร์ชันนี้ยังไม่มี rate limiting / account lockout แนะนำเพิ่มการจำกัดการลองรหัสก่อนใช้งานจริงกับข้อมูลอ่อนไหว และพิจารณาใช้ Supabase Auth/MFA ในระยะต่อไป
- โปรเจกต์นี้เป็นเว็บแอปใช้งานจริงเมื่อเชื่อมต่อ Supabase/Netlify แต่ยัง **ไม่ได้ทดสอบการ Deploy ในบัญชีของคุณ**
- ทุกคนที่รู้ PIN ใด PIN หนึ่งมีสิทธิ์บันทึกรายการเท่ากัน ไม่มีการแยกสิทธิ์ผู้ใช้
- ไม่รองรับการแก้ไขหรือลบธุรกรรมโดยตรง เพื่อลดความเสี่ยงยอดผิด หากบันทึกผิดให้ลงรายการปรับปรุงอย่างมีหลักฐาน
- ประวัติธุรกรรมแสดง 500 รายการล่าสุดใน V1 (ข้อมูลทั้งหมดเก็บในฐานข้อมูล)
- หน้ารายงานเป็นยอดสะสมทั้งหมด ไม่ใช่กรองรายเดือนใน V1
- ควรสำรองข้อมูลเป็นประจำ และเปิดการป้องกันบัญชี Supabase/Netlify ด้วย MFA

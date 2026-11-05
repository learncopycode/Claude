/* The hadith behind each dhikr (English meaning), shown in-app.
   Only well-known narrations are quoted; references open sunnah.com to check. */
const TASBIH_HADITH = { ref: "Sahih Muslim 597", text: "Whoever glorifies Allah (SubhanAllah) 33 times after every prayer, praises Allah (Alhamdulillah) 33 times and declares His greatness (Allahu Akbar) 33 times, making 99, and completes the hundred by saying “La ilaha illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa huwa ‘ala kulli shay’in qadir”, his sins will be forgiven even if they are like the foam of the sea." };
const QULS_HADITH = { ref: "Sunan Abi Dawud 5082", text: "The Prophet ﷺ said: Recite “Qul huwallahu ahad” and the two Mu‘awwidhatayn (Al-Falaq and An-Nas) three times in the evening and in the morning; they will suffice you against everything." };
const HADITH = {
  "subhanallah": TASBIH_HADITH, "alhamdulillah": TASBIH_HADITH, "allahuakbar": TASBIH_HADITH,
  "tahlil-complete": { ref: "Sahih al-Bukhari 6403", text: "Whoever says “La ilaha illallahu wahdahu la sharika lah, lahul-mulku wa lahul-hamdu wa huwa ‘ala kulli shay’in qadir” one hundred times in a day will have the reward of freeing ten slaves; a hundred good deeds will be written for him and a hundred bad deeds erased, and it will be a protection for him from Shaytan for that day until evening. No one will bring anything better, except someone who did more." },
  "la-ilaha-illallah": { ref: "Jami‘ at-Tirmidhi 3383", text: "The Prophet ﷺ said: The best remembrance is “La ilaha illallah”, and the best supplication is “Alhamdulillah”." },
  "subhanallahi-wa-bihamdihi": { ref: "Sahih al-Bukhari 6405", text: "Whoever says “SubhanAllahi wa bihamdihi” one hundred times a day will have his sins forgiven, even if they are like the foam of the sea." },
  "subhanallahil-azim": { ref: "Sahih al-Bukhari 6682", text: "Two words are light on the tongue, heavy on the scale, and beloved to the Most Merciful: “SubhanAllahi wa bihamdihi, SubhanAllahil-‘Azim”." },
  "baqiyat": { ref: "Sahih Muslim 2137", text: "The most beloved words to Allah are four: SubhanAllah, Alhamdulillah, La ilaha illallah and Allahu Akbar. It does not matter which of them you begin with." },
  "hawqala": { ref: "Sahih al-Bukhari 6384", text: "The Prophet ﷺ said: O ‘Abdullah ibn Qays, shall I not tell you of a treasure from the treasures of Paradise? Say: “La hawla wa la quwwata illa billah”." },
  "adada-khalqihi": { ref: "Sahih Muslim 2726", text: "The Prophet ﷺ left Juwayriyah early in the morning while she sat in her place of prayer, and returned late in the morning to find her still sitting there. He said: After leaving you I said four phrases three times; if they were weighed against all you have said since morning, they would outweigh it: “SubhanAllahi wa bihamdihi, ‘adada khalqihi, wa rida nafsihi, wa zinata ‘arshihi, wa midada kalimatihi”." },
  "salawat": { ref: "Sahih Muslim 408", text: "The Prophet ﷺ said: Whoever sends blessings upon me once, Allah sends blessings upon him ten times." },
  "astaghfirullah": { ref: "Sahih Muslim 2702", text: "The Prophet ﷺ said: O people, turn to Allah in repentance, for I turn to Him in repentance a hundred times a day." },
  "astaghfirullah-atubu": { ref: "Sahih al-Bukhari 6307", text: "The Prophet ﷺ said: By Allah, I seek Allah's forgiveness and turn to Him in repentance more than seventy times a day." },
  "sayyid-istighfar": { ref: "Sahih al-Bukhari 6306", text: "This is the master of seeking forgiveness. Whoever says it during the day with firm faith in it and dies that day before evening will be among the people of Paradise; and whoever says it at night with firm faith and dies before morning will be among the people of Paradise." },
  "laylatul-qadr": { ref: "Jami‘ at-Tirmidhi 3513", text: "‘A’ishah asked: O Messenger of Allah, if I know which night is Laylat al-Qadr, what should I say in it? He said: Say, “Allahumma innaka ‘afuwwun tuhibbul-‘afwa fa‘fu ‘anni”." },
  "dhun-nun": { ref: "Jami‘ at-Tirmidhi 3505", text: "The supplication of Dhun-Nun (Yunus) when he called upon Allah in the belly of the whale was: “La ilaha illa anta subhanaka inni kuntu minaz-zalimin.” No Muslim supplicates with it for anything except that Allah answers him." },
  "bismillah-la-yadurr": { ref: "Sunan Abi Dawud 5088", text: "Whoever says three times in the morning and three times in the evening: “Bismillahil-ladhi la yadurru ma‘as-mihi shay’un fil-ardi wa la fis-sama’i wa huwas-sami‘ul-‘alim”, nothing will harm him." },
  "raditu": { ref: "Sunan Abi Dawud 5072", text: "Whoever says in the morning and evening: “Raditu billahi rabba, wa bil-Islami dina, wa bi-Muhammadin nabiyya”, it is a promise upon Allah to please him on the Day of Resurrection." },
  "hasbiyallah": { ref: "Sunan Abi Dawud 5081", text: "Abu ad-Darda’ said: Whoever says seven times in the morning and evening “Hasbiyallahu la ilaha illa huwa, ‘alayhi tawakkaltu wa huwa rabbul-‘arshil-‘azim”, Allah will suffice him in whatever concerns him. (Scholars differ on whether this is the Prophet's words or Abu ad-Darda’s.)" },
  "auzu-bikalimat": { ref: "Sahih Muslim 2708", text: "The Prophet ﷺ said: Whoever stops at a place and says “A‘udhu bikalimatillahit-tammati min sharri ma khalaq”, nothing will harm him until he leaves that place." },
  "hasbunallah": { ref: "Sahih al-Bukhari 4563", text: "Ibn ‘Abbas said: “Hasbunallahu wa ni‘mal-wakil” was said by Ibrahim when he was thrown into the fire, and by Muhammad ﷺ when people said to him: The people have gathered against you, so fear them. But it only increased them in faith." },
  "muqallib": { ref: "Jami‘ at-Tirmidhi 2140", text: "Anas said: The Messenger of Allah ﷺ used to say often: “Ya Muqallibal-qulub, thabbit qalbi ‘ala dinik” (O Turner of hearts, keep my heart firm upon Your religion)." },
  "ainni": { ref: "Sunan Abi Dawud 1522", text: "The Prophet ﷺ took Mu‘adh by the hand and said: O Mu‘adh, by Allah, I love you. I advise you, O Mu‘adh, never to leave saying after every prayer: “Allahumma a‘inni ‘ala dhikrika wa shukrika wa husni ‘ibadatik”." },
  "hamm-hazan": { ref: "Sahih al-Bukhari 6369", text: "Anas said: The Prophet ﷺ used to say: “Allahumma inni a‘udhu bika minal-hammi wal-hazan, wal-‘ajzi wal-kasal, wal-bukhli wal-jubn, wa dala‘id-dayni wa ghalabatir-rijal.”" },
  "karb": { ref: "Sahih al-Bukhari 6346", text: "Ibn ‘Abbas said: At times of distress the Prophet ﷺ used to say: “La ilaha illallahul-‘azimul-halim, la ilaha illallahu rabbul-‘arshil-‘azim, la ilaha illallahu rabbus-samawati wa rabbul-ardi wa rabbul-‘arshil-karim.”" },
  "rabbana-atina": { ref: "Sahih al-Bukhari 6389", text: "Anas said: The supplication the Prophet ﷺ made most often was: “Allahumma rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina ‘adhaban-nar.”" },
  "sleep": { ref: "Sahih al-Bukhari 6324", text: "When the Prophet ﷺ went to bed he would say: “Bismika Allahumma amutu wa ahya”, and when he woke up he would say: “Alhamdu lillahil-ladhi ahyana ba‘da ma amatana wa ilayhin-nushur.”" },
  "leaving-home": { ref: "Sunan Abi Dawud 5095", text: "Whoever says when leaving his house: “Bismillah, tawakkaltu ‘alallah, wa la hawla wa la quwwata illa billah”, it is said to him: You are guided, you are sufficed and you are protected, and the devil turns away from him." },
  "after-eating": { ref: "Sunan Abi Dawud 4023", text: "Whoever eats food and then says: “Alhamdu lillahil-ladhi at‘amani hadha wa razaqanihi min ghayri hawlin minni wa la quwwah”, his past sins will be forgiven." },
  "travel": { ref: "Sahih Muslim 1342", text: "Ibn ‘Umar said: When the Messenger of Allah ﷺ mounted his camel to set out on a journey, he said “Allahu Akbar” three times, then: “Subhanal-ladhi sakhkhara lana hadha wa ma kunna lahu muqrinin, wa inna ila rabbina lamunqalibun.”" },
  "masjid": { ref: "Sahih Muslim 713", text: "The Prophet ﷺ said: When one of you enters the masjid, let him say: “Allahummaf-tah li abwaba rahmatik”, and when he leaves, let him say: “Allahumma inni as’aluka min fadlik.”" },
  "visiting-sick": { ref: "Sahih al-Bukhari 3616", text: "When the Prophet ﷺ visited a sick person he would say: “La ba’sa, tahurun in sha’ Allah” (No harm; it is a purification, if Allah wills)." },
  "rain": { ref: "Sahih al-Bukhari 1032", text: "‘A’ishah said: When the Messenger of Allah ﷺ saw rain he would say: “Allahumma sayyiban nafi‘a” (O Allah, make it a beneficial rain)." },
  "quran-2:255": { ref: "Sahih al-Bukhari 2311", text: "When you go to bed, recite Ayat al-Kursi; a guardian from Allah will remain with you and no devil will come near you until morning. The Prophet ﷺ said of this advice: He has told you the truth." },
  "quran-112": QULS_HADITH, "quran-113": QULS_HADITH, "quran-114": QULS_HADITH,
  "waking": { ref: "Sahih al-Bukhari 6324", text: "When the Prophet ﷺ woke up he would say: “Alhamdu lillahil-ladhi ahyana ba‘da ma amatana wa ilayhin-nushur.”" },
};
const NAMES_HADITH = { ref: "Sahih al-Bukhari 2736", text: "The Prophet ﷺ said: Allah has ninety-nine names, one hundred less one. Whoever enumerates them will enter Paradise." };
/* A link to check a source: Quran verses open quran.com, hadith search sunnah.com. */
function sourceLink(ref) {
  if (!ref) return { label: "", url: "#" };
  const q = /(?:Quran|[A-Z][\w‘’' -]*) (\d+):(\d+)/.exec(ref || "");
  if (q) return { label: "Open on quran.com", url: `https://quran.com/${q[1]}/${q[2]}` };
  return { label: "Check on sunnah.com", url: "https://sunnah.com/search?q=" + encodeURIComponent((ref || "").replace(/Sahih |Sunan |Jami‘ /, "")) };
}

/**
 * AI Communication Assistant - Unified Mobile Interface Controller
 * Powered by GPS Location Detection & Situational Message Delivery
 * Situational Contexts: Supermarkets, Popular Restaurants, Banks, Hospitals, and Pharmacies.
 * Includes interactive OpenStreetMap / Leaflet Area Map, Sri Lanka Hospitals display & Outside Predefined Facility Handling.
 */

document.addEventListener('DOMContentLoaded', () => {
  // Elements
  const statusTime = document.getElementById('status-time');
  const navButtons = document.querySelectorAll('.bottom-nav-btn');
  const tabPanels = document.querySelectorAll('.tab-content-panel');
  const customTypingTrigger = document.getElementById('custom-typing-trigger');
  
  // Modals & Drawers
  const customSheetBackdrop = document.getElementById('custom-sheet-backdrop');
  const closeSheetBtn = document.getElementById('close-sheet-btn');
  const customInputText = document.getElementById('custom-input-text');
  const showCustomFullscreenBtn = document.getElementById('show-custom-fullscreen-btn');
  const speakCustomBtn = document.getElementById('speak-custom-btn');
  const chipBtns = document.querySelectorAll('.chip-btn');
  
  const billboardModal = document.getElementById('billboard-modal');
  const billboardBackBtn = document.getElementById('billboard-back-btn');
  const billboardText = document.getElementById('billboard-text');
  const billboardIcon = document.getElementById('billboard-icon');
  const billboardFlipBtn = document.getElementById('billboard-flip-btn');
  const billboardSpeakBtn = document.getElementById('billboard-speak-btn');
  const billboardFavBtn = document.getElementById('billboard-fav-btn');
  const billboardCenter = document.getElementById('billboard-center');
  
  const menuBtn = document.getElementById('menu-btn');
  const drawerBackdrop = document.getElementById('drawer-backdrop');
  const closeDrawerBtn = document.getElementById('close-drawer-btn');
  
  // GPS Dialog, Strip & Controls
  const gpsTargetBtn = document.getElementById('gps-target-btn');
  const liveBadgeBtn = document.getElementById('live-badge-btn');
  const gpsDialogBackdrop = document.getElementById('gps-dialog-backdrop');
  const closeGpsDialogBtn = document.getElementById('close-gps-dialog-btn');
  const runLiveGpsBtn = document.getElementById('run-live-gps-btn');
  const previewLiveGpsBtn = document.getElementById('preview-live-gps-btn');
  const previewOpenSimBtn = document.getElementById('preview-open-sim-btn');
  const gpsStripRecheck = document.getElementById('gps-strip-recheck');
  const gpsStripStatus = document.getElementById('gps-strip-status');
  const gpsToast = document.getElementById('gps-scan-toast');
  const gpsToastText = document.getElementById('gps-toast-text');
  
  const previewFrameToggle = document.getElementById('preview-frame-toggle');
  const phoneMockup = document.getElementById('phone-mockup');
  
  const historyList = document.getElementById('history-list');
  const historyEmpty = document.getElementById('history-empty');
  const clearHistoryBtn = document.getElementById('clear-history-btn');
  const favoritesList = document.getElementById('favorites-list');
  const favoritesEmpty = document.getElementById('favorites-empty');
  const clearFavsBtn = document.getElementById('clear-favs-btn');

  // Default datasets for Hospital Categories
  const HOSPITAL_DEFAULT_CATEGORIES = {
    'basic-comm': [
      { template_en: "I am deaf.", template_si: "මම බිහිරි කෙනෙක්.", icon: "fa-ear-deaf" },
      { template_en: "I cannot speak.", template_si: "මට කතා කරන්න බැහැ.", icon: "fa-volume-xmark" },
      { template_en: "Please write down your message.", template_si: "කරුණාකර ඔබේ පණිවිඩය ලියන්න.", icon: "fa-pen-to-square" },
      { template_en: "Please speak slowly and face me.", template_si: "කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.", icon: "fa-face-smile" },
      { template_en: "Please wait a moment.", template_si: "කරුණාකර මොහොතක් රැඳී සිටින්න.", icon: "fa-clock" },
      { template_en: "Thank you.", template_si: "ස්තූතියි.", icon: "fa-hands-clapping" },
      { template_en: "Yes.", template_si: "ඔව්.", icon: "fa-circle-check" },
      { template_en: "No.", template_si: "නැහැ.", icon: "fa-circle-xmark" },
      { template_en: "I do not understand.", template_si: "මට තේරෙන්නේ නැහැ.", icon: "fa-circle-question" },
      { template_en: "Please repeat that.", template_si: "කරුණාකර නැවත කියන්න.", icon: "fa-rotate-right" }
    ],
    'reception': [
      { template_en: "I need help.", template_si: "මට උදව්වක් අවශ්යයි.", icon: "fa-handshake-angle" },
      { template_en: "Where is the reception?", template_si: "පිළිගැනීමේ කවුන්ටරය කොහෙද?", icon: "fa-bell-concierge" },
      { template_en: "I want to register as a new patient.", template_si: "මට නව රෝගියෙකු ලෙස ලියාපදිංචි වීමට අවශ්යයි.", icon: "fa-user-plus" },
      { template_en: "I have an appointment.", template_si: "මට වේලාවක් වෙන්කරගෙන තියෙනවා.", icon: "fa-calendar-check" },
      { template_en: "I want to make an appointment.", template_si: "මට වේලාවක් වෙන්කරගන්න ඕනේ.", icon: "fa-calendar-plus" },
      { template_en: "Which counter should I go to?", template_si: "මම යා යුත්තේ කුමන කවුන්ටරයට ද?", icon: "fa-arrow-right-to-bracket" },
      { template_en: "How long is the waiting time?", template_si: "බලා සිටිය යුතු කාලය කොපමණ ද?", icon: "fa-hourglass-half" },
      { template_en: "Where do I get a token number?", template_si: "ටෝකන් අංකය ලබාගන්නේ කොහෙන්ද?", icon: "fa-ticket" },
      { template_en: "Here is my ID card.", template_si: "මෙන්න මගේ හැඳුනුම්පත.", icon: "fa-id-card" },
      { template_en: "Here is my clinic book.", template_si: "මෙන්න මගේ සායන පොත.", icon: "fa-book-medical" }
    ],
    'directions': [
      { template_en: "Where is the Outpatient Department (OPD)?", template_si: "බාහිර රෝගී අංශය (OPD) කොහෙද?", icon: "fa-hospital-user" },
      { template_en: "Where is the emergency unit?", template_si: "හදිසි අනතුරු අංශය කොහෙද?", icon: "fa-truck-medical" },
      { template_en: "Where is the pharmacy?", template_si: "ඖෂධ ශාලාව කොහෙද?", icon: "fa-pills" },
      { template_en: "Where is the laboratory?", template_si: "රසායනාගාරය කොහෙද?", icon: "fa-flask-vial" },
      { template_en: "Where is the X-ray room?", template_si: "X-ray කාමරය කොහෙද?", icon: "fa-x-ray" },
      { template_en: "Where is the toilet?", template_si: "වැසිකිළිය කොහෙද?", icon: "fa-restroom" },
      { template_en: "Where is the lift?", template_si: "සෝපානය කොහෙද?", icon: "fa-elevator" },
      { template_en: "Where is the payment counter?", template_si: "ගෙවීම් කවුන්ටරය කොහෙද?", icon: "fa-cash-register" },
      { template_en: "Where is the ward?", template_si: "වාට්ටුව කොහෙද?", icon: "fa-bed-pulse" },
      { template_en: "Can you show me the way?", template_si: "මට පාර පෙන්වන්න පුළුවන් ද?", icon: "fa-diamond-turn-right" }
    ],
    'symptoms': [
      { template_en: "I am in pain.", template_si: "මට වේදනාවක් තියෙනවා.", icon: "fa-circle-exclamation" },
      { template_en: "I have a headache.", template_si: "මට හිසරදයක් තියෙනවා.", icon: "fa-head-side-virus" },
      { template_en: "I have a fever.", template_si: "මට උණ තියෙනවා.", icon: "fa-temperature-high" },
      { template_en: "I have a cough.", template_si: "මට කැස්සක් තියෙනවා.", icon: "fa-lungs" },
      { template_en: "I have chest pain.", template_si: "මට පපුවේ වේදනාවක් තියෙනවා.", icon: "fa-heart-crack" },
      { template_en: "I have difficulty breathing.", template_si: "මට හුස්ම ගැනීමට අපහසුයි.", icon: "fa-wind" },
      { template_en: "I have stomach pain.", template_si: "මට බඩේ කැක්කුමක් තියෙනවා.", icon: "fa-person-dots-from-line" },
      { template_en: "I feel dizzy.", template_si: "මට හිස කැරකෙනවා.", icon: "fa-rotate" },
      { template_en: "I feel nauseous.", template_si: "මට වමනය යන්න වගේ.", icon: "fa-face-dizzy" },
      { template_en: "I have been vomiting.", template_si: "මම වමනය කරනවා.", icon: "fa-face-frown-open" },
      { template_en: "I have diarrhoea.", template_si: "මට පාචනයක් තියෙනවා.", icon: "fa-toilet" },
      { template_en: "I have back pain.", template_si: "මට කොන්දේ වේදනාවක් තියෙනවා.", icon: "fa-child" },
      { template_en: "I have a toothache.", template_si: "මට දත් කැක්කුමක් තියෙනවා.", icon: "fa-tooth" },
      { template_en: "I have a sore throat.", template_si: "මට උගුරේ අමාරුවක් තියෙනවා.", icon: "fa-viruses" },
      { template_en: "I have a skin rash.", template_si: "මගේ සමේ කැසීමක් සහ පැල්ලම් තියෙනවා.", icon: "fa-hand-dots" },
      { template_en: "I have a problem with my eye.", template_si: "මගේ ඇසට ප්රශ්නයක් තියෙනවා.", icon: "fa-eye" },
      { template_en: "I have a problem with my ear.", template_si: "මගේ කණට ප්රශ්නයක් තියෙනවා.", icon: "fa-ear-listen" },
      { template_en: "I am bleeding.", template_si: "මගෙන් ලේ ගලනවා.", icon: "fa-droplet" },
      { template_en: "I feel very weak.", template_si: "මම හරිම දුර්වලයි.", icon: "fa-battery-quarter" }
    ],
    'emergency': [
      { template_en: "This is an emergency!", template_si: "මෙය හදිසි අවස්ථාවක්!", icon: "fa-triangle-exclamation" },
      { template_en: "Please call a doctor immediately.", template_si: "කරුණාකර වහාම වෛද්යවරයෙකු කැඳවන්න.", icon: "fa-user-doctor" },
      { template_en: "Please call a nurse.", template_si: "කරුණාකර හෙදියක් කැඳවන්න.", icon: "fa-user-nurse" },
      { template_en: "I need an ambulance.", template_si: "මට ගිලන් රථයක් අවශ්යයි.", icon: "fa-truck-medical" },
      { template_en: "I think I am having a heart attack.", template_si: "මට හෘදයාබාධයක් වගේ දැනෙනවා.", icon: "fa-heart-crack" },
      { template_en: "I feel like I am going to faint.", template_si: "මට සිහිසුන් වෙන්න යනවා වගේ.", icon: "fa-person-falling" },
      { template_en: "I have had an accident.", template_si: "මට අනතුරක් වුණා.", icon: "fa-car-burst" },
      { template_en: "Please call my family.", template_si: "කරුණාකර මගේ පවුලේ අයට කතා කරන්න.", icon: "fa-phone" }
    ],
    'medical-history': [
      { template_en: "I have diabetes.", template_si: "මට දියවැඩියාව තියෙනවා.", icon: "fa-droplet" },
      { template_en: "I have high blood pressure.", template_si: "මට අධි රුධිර පීඩනය තියෙනවා.", icon: "fa-heart-pulse" },
      { template_en: "I have asthma.", template_si: "මට ඇදුම තියෙනවා.", icon: "fa-lungs" },
      { template_en: "I have a heart condition.", template_si: "මට හෘද රෝගයක් තියෙනවා.", icon: "fa-heart" },
      { template_en: "I am allergic to a medicine.", template_si: "මට ඖෂධයකට අසාත්මිකතාවක් තියෙනවා.", icon: "fa-capsules" },
      { template_en: "I am allergic to penicillin.", template_si: "මට පෙනිසිලින් වලට අසාත්මිකයි.", icon: "fa-shield-halved" },
      { template_en: "I am pregnant.", template_si: "මම ගර්භණීයි.", icon: "fa-person-breastfeeding" },
      { template_en: "I take regular medication.", template_si: "මම නිතර ඖෂධ ගන්නවා.", icon: "fa-pills" },
      { template_en: "I have no known allergies.", template_si: "මට කිසිදු අසාත්මිකතාවක් නැහැ.", icon: "fa-circle-check" },
      { template_en: "I have had surgery before.", template_si: "මට කලින් ශල්යකර්මයක් කරලා තියෙනවා.", icon: "fa-scissors" },
      { template_en: "I need a blood test.", template_si: "මට රුධිර පරීක්ෂාවක් අවශ්යයි.", icon: "fa-vial" },
      { template_en: "I have had this problem since yesterday.", template_si: "මට මේ ප්රශ්නය ඊයේ සිට තියෙනවා.", icon: "fa-calendar-day" },
      { template_en: "I have had this for several days.", template_si: "මට මේක දවස් කිහිපයක් සිට තියෙනවා.", icon: "fa-calendar-week" },
      { template_en: "This is the first time I have had this.", template_si: "මට මෙය පළමු වතාවටයි.", icon: "fa-circle-exclamation" }
    ],
    'doctor-consultation': [
      { template_en: "Please explain my condition in writing.", template_si: "කරුණාකර මගේ තත්ත්වය ලියා පැහැදිලි කරන්න.", icon: "fa-pen-to-square" },
      { template_en: "What is my diagnosis?", template_si: "මගේ රෝග විනිශ්චය කුමක්ද?", icon: "fa-stethoscope" },
      { template_en: "Is it serious?", template_si: "මෙය බරපතල ද?", icon: "fa-triangle-exclamation" },
      { template_en: "Do I need tests?", template_si: "මට පරීක්ෂණ අවශ්යයි ද?", icon: "fa-microscope" },
      { template_en: "Do I need surgery?", template_si: "මට ශල්යකර්මයක් අවශ්යයි ද?", icon: "fa-syringe" },
      { template_en: "Do I need to stay in the hospital?", template_si: "මට රෝහලේ නැවතී සිටිය යුතු ද?", icon: "fa-hospital" },
      { template_en: "What medicine should I take?", template_si: "මම ගත යුතු ඖෂධ මොනවාද?", icon: "fa-pills" },
      { template_en: "How many times a day should I take it?", template_si: "දවසකට කී වතාවක් ගත යුතුද?", icon: "fa-clock" },
      { template_en: "Are there any side effects?", template_si: "අතුරු ආබාධ තියෙනවා ද?", icon: "fa-circle-info" },
      { template_en: "Can I eat before the test?", template_si: "පරීක්ෂණයට පෙර මට කෑමට පුළුවන් ද?", icon: "fa-utensils" },
      { template_en: "When should I come again?", template_si: "මම නැවත එන්න ඕනේ කවදාද?", icon: "fa-calendar-plus" },
      { template_en: "Can you write down the instructions?", template_si: "උපදෙස් ලියා දෙන්න පුළුවන් ද?", icon: "fa-file-lines" },
      { template_en: "Is a sign language interpreter available?", template_si: "සංඥා භාෂා පරිවර්තකයෙකු ඉන්නවාද?", icon: "fa-hands-asl-interpreting" },
      { template_en: "Please point to where it hurts or show me.", template_si: "කරුණාකර රිදෙන තැන පෙන්වන්න.", icon: "fa-hand-pointer" }
    ],
    'procedures-comfort': [
      { template_en: "Please tell me before you examine me.", template_si: "පරීක්ෂා කිරීමට පෙර කරුණාකර මට දන්වන්න.", icon: "fa-circle-info" },
      { template_en: "Please show me what I need to do.", template_si: "මා කළ යුත්තේ කුමක්දැයි කරුණාකර පෙන්වන්න.", icon: "fa-arrow-pointer" },
      { template_en: "I am afraid.", template_si: "මට බයයි.", icon: "fa-face-frown" },
      { template_en: "Please be gentle, it hurts.", template_si: "කරුණාකර සෙමින් කරන්න, රිදෙනවා.", icon: "fa-hand-holding" },
      { template_en: "I agree to the procedure.", template_si: "මම මෙම ක්රියාපටිපාටියට එකඟයි.", icon: "fa-circle-check" },
      { template_en: "I need more information before I agree.", template_si: "එකඟ වීමට පෙර මට තව තොරතුරු අවශ්යයි.", icon: "fa-circle-question" },
      { template_en: "Please let me know when it is my turn.", template_si: "මගේ වාරය පැමිණි විට කරුණාකර මට දන්වන්න.", icon: "fa-clock" },
      { template_en: "Please tap my shoulder when it is my turn.", template_si: "මගේ වාරය පැමිණි විට කරුණාකර මගේ උරහිසට තට්ටු කරන්න.", icon: "fa-hand" }
    ],
    'pharmacy-billing': [
      { template_en: "Please write down how to use this medicine.", template_si: "මෙම ඖෂධය භාවිතා කරන ආකාරය ලියා දෙන්න.", icon: "fa-prescription-bottle-medical" },
      { template_en: "How much is the bill?", template_si: "බිල කීයද?", icon: "fa-money-bill-wave" },
      { template_en: "Can I pay by card?", template_si: "කාඩ්පතෙන් ගෙවන්න පුළුවන් ද?", icon: "fa-credit-card" },
      { template_en: "Where can I collect my reports?", template_si: "මගේ වාර්තා ලබාගන්නේ කොහෙන්ද?", icon: "fa-file-invoice" },
      { template_en: "May I go home now?", template_si: "මට දැන් ගෙදර යන්න පුළුවන් ද?", icon: "fa-house-chimney" },
      { template_en: "Thank you for your help.", template_si: "ඔබේ උදව්වට ස්තූතියි.", icon: "fa-hands-clapping" }
    ]
  };

  let cachedHospitalCategories = {
    'basic-comm': [...HOSPITAL_DEFAULT_CATEGORIES['basic-comm']],
    'reception': [...HOSPITAL_DEFAULT_CATEGORIES['reception']],
    'directions': [...HOSPITAL_DEFAULT_CATEGORIES['directions']],
    'symptoms': [...HOSPITAL_DEFAULT_CATEGORIES['symptoms']],
    'emergency': [...HOSPITAL_DEFAULT_CATEGORIES['emergency']],
    'medical-history': [...HOSPITAL_DEFAULT_CATEGORIES['medical-history']],
    'doctor-consultation': [...HOSPITAL_DEFAULT_CATEGORIES['doctor-consultation']],
    'procedures-comfort': [...HOSPITAL_DEFAULT_CATEGORIES['procedures-comfort']],
    'pharmacy-billing': [...HOSPITAL_DEFAULT_CATEGORIES['pharmacy-billing']]
  };
  let currentActiveHospitalCategory = null;

  // Sri Lanka Major Hospitals Dataset
  const SRI_LANKA_HOSPITALS_DATA = [
    {
      id: 'nhsl-colombo',
      name: 'National Hospital of Sri Lanka (NHSL)',
      short_name: 'NHSL Colombo',
      city: 'Colombo 10',
      district: 'Colombo',
      province: 'Western',
      type: 'National Teaching Hospital',
      lat: 6.9197,
      lon: 79.8693,
      emergency: '1990 / +94 11 269 1111'
    },
    {
      id: 'asiri-central',
      name: 'Asiri Central Hospital',
      short_name: 'Asiri Central',
      city: 'Norris Canal Rd, Colombo 10',
      district: 'Colombo',
      province: 'Western',
      type: 'Private Multi-Specialty Hospital',
      lat: 6.9248,
      lon: 79.8647,
      emergency: '+94 11 466 5500'
    },
    {
      id: 'nawaloka-colombo',
      name: 'Nawaloka Hospital',
      short_name: 'Nawaloka Hospital',
      city: 'Deshamanya H.K. Dharmadasa Mw, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      type: 'Private Multi-Specialty Hospital',
      lat: 6.9243,
      lon: 79.8524,
      emergency: '+94 11 557 7111'
    },
    {
      id: 'kalubowila-teaching',
      name: 'Colombo South Teaching Hospital (Kalubowila)',
      short_name: 'Kalubowila Hospital',
      city: 'Kalubowila / Dehiwala',
      district: 'Colombo',
      province: 'Western',
      type: 'Teaching Hospital',
      lat: 6.8732,
      lon: 79.8789,
      emergency: '1990 / +94 11 276 3066'
    },
    {
      id: 'lanka-hospitals',
      name: 'The Lanka Hospitals',
      short_name: 'Lanka Hospitals',
      city: 'Elvitigala Mw, Narahenpita, Colombo 05',
      district: 'Colombo',
      province: 'Western',
      type: 'Private Multi-Specialty Hospital',
      lat: 6.8953,
      lon: 79.8837,
      emergency: '+94 11 543 0000 / 1566'
    },
    {
      id: 'durdans-colombo',
      name: 'Durdans Hospital',
      short_name: 'Durdans Hospital',
      city: 'Alfred Place, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      type: 'Private Hospital',
      lat: 6.8988,
      lon: 79.8548,
      emergency: '+94 11 214 0000 / 1344'
    },
    {
      id: 'asiri-surgical',
      name: 'Asiri Surgical Hospital',
      short_name: 'Asiri Surgical',
      city: 'Kirimandala Mw, Narahenpita, Colombo 05',
      district: 'Colombo',
      province: 'Western',
      type: 'Private Surgical Hospital',
      lat: 6.8924,
      lon: 79.8842,
      emergency: '+94 11 452 4400'
    },
    {
      id: 'lrh-colombo',
      name: 'Lady Ridgeway Hospital for Children (LRH)',
      short_name: 'LRH Children Hospital',
      city: 'Danister De Silva Mw, Colombo 08',
      district: 'Colombo',
      province: 'Western',
      type: 'Pediatric Teaching Hospital',
      lat: 6.9238,
      lon: 79.8761,
      emergency: '1990 / +94 11 269 3711'
    },
    {
      id: 'castle-street',
      name: 'Castle Street Hospital for Women',
      short_name: 'Castle Street Hospital',
      city: 'Castle Street, Colombo 08',
      district: 'Colombo',
      province: 'Western',
      type: 'Women & Maternity Teaching Hospital',
      lat: 6.9142,
      lon: 79.8856,
      emergency: '+94 11 269 6231'
    },
    {
      id: 'ragama-teaching',
      name: 'Colombo North Teaching Hospital (Ragama)',
      short_name: 'Ragama Hospital',
      city: 'Ragama',
      district: 'Gampaha',
      province: 'Western',
      type: 'Teaching Hospital',
      lat: 7.0286,
      lon: 79.9190,
      emergency: '1990 / +94 11 295 9261'
    },
    {
      id: 'sri-jayewardenepura',
      name: 'Sri Jayewardenepura General Hospital',
      short_name: 'SJGH Kotte',
      city: 'Thalapathpitiya, Nugegoda',
      district: 'Colombo',
      province: 'Western',
      type: 'General Hospital',
      lat: 6.8772,
      lon: 79.9272,
      emergency: '+94 11 277 8610'
    },
    {
      id: 'negombo-hospital',
      name: 'District General Hospital Negombo',
      short_name: 'Negombo Hospital',
      city: 'Colombo Rd, Negombo',
      district: 'Gampaha',
      province: 'Western',
      type: 'District General Hospital',
      lat: 7.2144,
      lon: 79.8452,
      emergency: '1990 / +94 31 222 2261'
    },
    {
      id: 'gampaha-hospital',
      name: 'District General Hospital Gampaha',
      short_name: 'Gampaha Hospital',
      city: 'Gampaha',
      district: 'Gampaha',
      province: 'Western',
      type: 'District General Hospital',
      lat: 7.0898,
      lon: 79.9934,
      emergency: '1990 / +94 33 222 2261'
    },
    {
      id: 'kandy-teaching',
      name: 'National Hospital Kandy',
      short_name: 'Kandy National Hospital',
      city: 'William Gopallawa Mw, Kandy',
      district: 'Kandy',
      province: 'Central',
      type: 'National Teaching Hospital',
      lat: 7.2885,
      lon: 80.6277,
      emergency: '1990 / +94 81 223 3337'
    },
    {
      id: 'karapitiya-teaching',
      name: 'Teaching Hospital Karapitiya (Galle)',
      short_name: 'Karapitiya Hospital Galle',
      city: 'Karapitiya, Galle',
      district: 'Galle',
      province: 'Southern',
      type: 'Teaching Hospital',
      lat: 6.0645,
      lon: 80.2285,
      emergency: '1990 / +94 91 223 2250'
    },
    {
      id: 'jaffna-teaching',
      name: 'Teaching Hospital Jaffna',
      short_name: 'Jaffna Hospital',
      city: 'Hospital Rd, Jaffna',
      district: 'Jaffna',
      province: 'Northern',
      type: 'Teaching Hospital',
      lat: 9.6644,
      lon: 80.0215,
      emergency: '1990 / +94 21 222 2261'
    },
    {
      id: 'anuradhapura-teaching',
      name: 'Teaching Hospital Anuradhapura',
      short_name: 'Anuradhapura Hospital',
      city: 'Maithripala Senanayake Mw, Anuradhapura',
      district: 'Anuradhapura',
      province: 'North Central',
      type: 'Teaching Hospital',
      lat: 8.3370,
      lon: 80.4045,
      emergency: '1990 / +94 25 222 2261'
    },
    {
      id: 'batticaloa-teaching',
      name: 'Teaching Hospital Batticaloa',
      short_name: 'Batticaloa Hospital',
      city: 'Hospital Rd, Batticaloa',
      district: 'Batticaloa',
      province: 'Eastern',
      type: 'Teaching Hospital',
      lat: 7.7126,
      lon: 81.6961,
      emergency: '1990 / +94 65 222 2261'
    },
    {
      id: 'panadura-hospital',
      name: 'Base Hospital Panadura',
      short_name: 'Panadura Hospital',
      city: 'Horana Rd, Panadura',
      district: 'Kalutara',
      province: 'Western',
      type: 'Base Hospital',
      lat: 6.7135,
      lon: 79.9074,
      emergency: '1990 / +94 38 223 2261'
    },
    {
      id: 'homagama-hospital',
      name: 'Base Hospital Homagama',
      short_name: 'Homagama Hospital',
      city: 'Homagama',
      district: 'Colombo',
      province: 'Western',
      type: 'Base Hospital',
      lat: 6.8436,
      lon: 80.0035,
      emergency: '1990 / +94 11 285 5261'
    }
  ];

  // Major Banks in Sri Lanka (State Commercial, Licensed Private, Foreign & Regional Banks)
  const SRI_LANKA_BANKS_DATA = [
    {
      id: 'boc-head-office',
      name: 'Bank of Ceylon (BOC) - Head Office',
      short_name: 'BOC Head Office',
      bank_name: 'Bank of Ceylon',
      branch: 'Head Office',
      city: 'BOC Square, Bank of Ceylon Mw, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      type: 'State Commercial Bank',
      lat: 6.9348,
      lon: 79.8436,
      hotline: '1975 / +94 11 220 4444',
      slug: 'bank'
    },
    {
      id: 'combank-head-office',
      name: 'Commercial Bank of Ceylon - Head Office',
      short_name: 'Commercial Bank HQ',
      bank_name: 'Commercial Bank',
      branch: 'Commercial House, Fort',
      city: 'Bristol St, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9340,
      lon: 79.8444,
      hotline: '+94 11 248 6000',
      slug: 'bank'
    },
    {
      id: 'peoples-bank-head-office',
      name: "People's Bank - Head Office",
      short_name: "People's Bank HQ",
      bank_name: "People's Bank",
      branch: 'Head Office',
      city: 'Sir Chittampalam A Gardiner Mw, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      type: 'State Commercial Bank',
      lat: 6.9312,
      lon: 79.8510,
      hotline: '1961 / +94 11 245 8100',
      slug: 'bank'
    },
    {
      id: 'hnb-towers',
      name: 'Hatton National Bank (HNB) - Head Office',
      short_name: 'HNB Towers Colombo',
      bank_name: 'Hatton National Bank',
      branch: 'HNB Towers',
      city: 'T.B. Jayah Mw, Colombo 10',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9208,
      lon: 79.8652,
      hotline: '+94 11 266 4664',
      slug: 'bank'
    },
    {
      id: 'sampath-bank-head-office',
      name: 'Sampath Bank - Head Office',
      short_name: 'Sampath Bank HQ',
      bank_name: 'Sampath Bank',
      branch: 'Head Office',
      city: 'Sir James Pieris Mw, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9205,
      lon: 79.8560,
      hotline: '+94 11 230 3050',
      slug: 'bank'
    },
    {
      id: 'seylan-towers',
      name: 'Seylan Bank - Head Office',
      short_name: 'Seylan Towers Colombo',
      bank_name: 'Seylan Bank',
      branch: 'Seylan Towers',
      city: 'Galle Rd, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9152,
      lon: 79.8505,
      hotline: '+94 11 200 8888',
      slug: 'bank'
    },
    {
      id: 'nsb-head-office',
      name: 'National Savings Bank (NSB) - Head Office',
      short_name: 'NSB Head Office',
      bank_name: 'National Savings Bank',
      branch: 'Head Office',
      city: 'Ananda Coomaraswamy Mw, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      type: 'State Savings Bank',
      lat: 6.9078,
      lon: 79.8570,
      hotline: '+94 11 237 9379',
      slug: 'bank'
    },
    {
      id: 'ntb-head-office',
      name: 'Nations Trust Bank (NTB) - Head Office',
      short_name: 'Nations Trust HQ',
      bank_name: 'Nations Trust Bank',
      branch: 'Head Office',
      city: 'Union Place, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9200,
      lon: 79.8580,
      hotline: '+94 11 471 1411',
      slug: 'bank'
    },
    {
      id: 'dfcc-head-office',
      name: 'DFCC Bank - Head Office',
      short_name: 'DFCC Bank HQ',
      bank_name: 'DFCC Bank',
      branch: 'Head Office',
      city: 'Galle Rd, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9180,
      lon: 79.8495,
      hotline: '+94 11 235 0000',
      slug: 'bank'
    },
    {
      id: 'pan-asia-head-office',
      name: 'Pan Asia Bank - Head Office',
      short_name: 'Pan Asia Bank HQ',
      bank_name: 'Pan Asia Bank',
      branch: 'Head Office',
      city: 'Galle Rd, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9030,
      lon: 79.8525,
      hotline: '+94 11 466 7222',
      slug: 'bank'
    },
    {
      id: 'hsbc-fort',
      name: 'HSBC Sri Lanka - Colombo Main Office',
      short_name: 'HSBC Fort Colombo',
      bank_name: 'HSBC',
      branch: 'Colombo Fort Branch',
      city: 'Sir Baron Jayatilaka Mw, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      type: 'International Commercial Bank',
      lat: 6.9360,
      lon: 79.8430,
      hotline: '+94 11 447 2200',
      slug: 'bank'
    },
    {
      id: 'standard-chartered-fort',
      name: 'Standard Chartered Bank - Main Office',
      short_name: 'Standard Chartered Fort',
      bank_name: 'Standard Chartered',
      branch: 'Sri Lanka Main Branch',
      city: 'Janadhipathi Mw, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      type: 'International Commercial Bank',
      lat: 6.9335,
      lon: 79.8420,
      hotline: '+94 11 248 0000',
      slug: 'bank'
    },
    {
      id: 'amana-bank-head-office',
      name: 'Amāna Bank - Corporate Office',
      short_name: 'Amāna Bank HQ',
      bank_name: 'Amāna Bank',
      branch: 'Corporate Office',
      city: 'Dharmapala Mw, Colombo 07',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9110,
      lon: 79.8620,
      hotline: '+94 11 775 6756',
      slug: 'bank'
    },
    {
      id: 'cargills-bank-head-office',
      name: 'Cargills Bank - Head Office',
      short_name: 'Cargills Bank HQ',
      bank_name: 'Cargills Bank',
      branch: 'Head Office',
      city: 'Maitland Crescent, Colombo 07',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9045,
      lon: 79.8665,
      hotline: '+94 11 764 0640',
      slug: 'bank'
    },
    {
      id: 'union-bank-head-office',
      name: 'Union Bank of Colombo - Head Office',
      short_name: 'Union Bank HQ',
      bank_name: 'Union Bank',
      branch: 'Head Office',
      city: 'Galle Rd, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 6.9090,
      lon: 79.8510,
      hotline: '+94 11 580 0800',
      slug: 'bank'
    },
    {
      id: 'boc-kandy-super',
      name: 'Bank of Ceylon (BOC) - Kandy Super Grade Branch',
      short_name: 'BOC Kandy Super Branch',
      bank_name: 'Bank of Ceylon',
      branch: 'Kandy Super Grade Branch',
      city: 'Dalada Veediya, Kandy',
      district: 'Kandy',
      province: 'Central',
      type: 'State Commercial Bank',
      lat: 7.2935,
      lon: 80.6360,
      hotline: '1975 / +94 81 223 4282',
      slug: 'bank'
    },
    {
      id: 'combank-kandy-city',
      name: 'Commercial Bank - Kandy City Branch',
      short_name: 'Commercial Bank Kandy',
      bank_name: 'Commercial Bank',
      branch: 'Kandy City Branch',
      city: 'Ward Street (Kotugodella Veediya), Kandy',
      district: 'Kandy',
      province: 'Central',
      type: 'Licensed Commercial Bank',
      lat: 7.2920,
      lon: 80.6345,
      hotline: '+94 81 222 4558',
      slug: 'bank'
    },
    {
      id: 'hnb-kandy',
      name: 'Hatton National Bank (HNB) - Kandy Branch',
      short_name: 'HNB Kandy Branch',
      bank_name: 'Hatton National Bank',
      branch: 'Kandy Main Branch',
      city: 'Dalada Veediya, Kandy',
      district: 'Kandy',
      province: 'Central',
      type: 'Licensed Commercial Bank',
      lat: 7.2940,
      lon: 80.6370,
      hotline: '+94 81 223 4381',
      slug: 'bank'
    },
    {
      id: 'peoples-bank-galle',
      name: "People's Bank - Galle Regional Branch",
      short_name: "People's Bank Galle",
      bank_name: "People's Bank",
      branch: 'Galle Regional Branch',
      city: 'Main Street, Galle',
      district: 'Galle',
      province: 'Southern',
      type: 'State Commercial Bank',
      lat: 6.0350,
      lon: 80.2160,
      hotline: '1961 / +94 91 223 4331',
      slug: 'bank'
    },
    {
      id: 'combank-galle-fort',
      name: 'Commercial Bank - Galle Fort Branch',
      short_name: 'Commercial Bank Galle Fort',
      bank_name: 'Commercial Bank',
      branch: 'Galle Fort Branch',
      city: 'Church Street, Galle Fort',
      district: 'Galle',
      province: 'Southern',
      type: 'Licensed Commercial Bank',
      lat: 6.0270,
      lon: 80.2175,
      hotline: '+94 91 223 4511',
      slug: 'bank'
    },
    {
      id: 'boc-jaffna-main',
      name: 'Bank of Ceylon (BOC) - Jaffna Main Branch',
      short_name: 'BOC Jaffna Main',
      bank_name: 'Bank of Ceylon',
      branch: 'Jaffna Main Branch',
      city: 'Hospital Rd, Jaffna',
      district: 'Jaffna',
      province: 'Northern',
      type: 'State Commercial Bank',
      lat: 9.6630,
      lon: 80.0165,
      hotline: '1975 / +94 21 222 2281',
      slug: 'bank'
    },
    {
      id: 'hnb-negombo',
      name: 'Hatton National Bank (HNB) - Negombo Main Branch',
      short_name: 'HNB Negombo Branch',
      bank_name: 'Hatton National Bank',
      branch: 'Negombo Main Branch',
      city: 'Greens Road, Negombo',
      district: 'Gampaha',
      province: 'Western',
      type: 'Licensed Commercial Bank',
      lat: 7.2100,
      lon: 79.8390,
      hotline: '+94 31 222 2841',
      slug: 'bank'
    },
    {
      id: 'sampath-kurunegala',
      name: 'Sampath Bank - Kurunegala Super Branch',
      short_name: 'Sampath Bank Kurunegala',
      bank_name: 'Sampath Bank',
      branch: 'Kurunegala Super Branch',
      city: 'Colombo Road, Kurunegala',
      district: 'Kurunegala',
      province: 'North Western',
      type: 'Licensed Commercial Bank',
      lat: 7.4850,
      lon: 80.3620,
      hotline: '+94 37 222 3991',
      slug: 'bank'
    },
    {
      id: 'combank-anuradhapura',
      name: 'Commercial Bank - Anuradhapura Branch',
      short_name: 'Commercial Bank Anuradhapura',
      bank_name: 'Commercial Bank',
      branch: 'Anuradhapura Branch',
      city: 'Maithripala Senanayake Mw, Anuradhapura',
      district: 'Anuradhapura',
      province: 'North Central',
      type: 'Licensed Commercial Bank',
      lat: 8.3310,
      lon: 80.4080,
      hotline: '+94 25 222 2771',
      slug: 'bank'
    },
    {
      id: 'peoples-bank-batticaloa',
      name: "People's Bank - Batticaloa Branch",
      short_name: "People's Bank Batticaloa",
      bank_name: "People's Bank",
      branch: 'Batticaloa Branch',
      city: 'Bar Road, Batticaloa',
      district: 'Batticaloa',
      province: 'Eastern',
      type: 'State Commercial Bank',
      lat: 7.7160,
      lon: 81.6990,
      hotline: '1961 / +94 65 222 2271',
      slug: 'bank'
    }
  ];

  // Major & Popular Restaurants in Sri Lanka (Famous Dining, Traditional, Seafood & Heritage Venues)
  const SRI_LANKA_RESTAURANTS_DATA = [
    {
      id: 'upalis-colombo',
      name: "Upali's by Nawaloka",
      short_name: "Upali's Colombo",
      restaurant_name: "Upali's by Nawaloka",
      cuisine: 'Authentic Sri Lankan Cuisine',
      branch: 'Colombo 07',
      city: 'C.W.W. Kannangara Mw, Town Hall, Colombo 07',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9115,
      lon: 79.8635,
      phone: '+94 11 269 5812',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'ministry-of-crab',
      name: 'Ministry of Crab',
      short_name: 'Ministry of Crab',
      restaurant_name: 'Ministry of Crab',
      cuisine: 'Seafood & Lagoon Crab Fine Dining',
      branch: 'Old Dutch Hospital',
      city: 'Old Dutch Hospital, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9345,
      lon: 79.8437,
      phone: '+94 11 540 2722',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'the-lagoon-cinnamon-grand',
      name: 'The Lagoon - Cinnamon Grand',
      short_name: 'The Lagoon',
      restaurant_name: 'The Lagoon',
      cuisine: 'Premium Seafood Market & Dining',
      branch: 'Cinnamon Grand',
      city: 'Galle Road, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9167,
      lon: 79.8492,
      phone: '+94 11 249 7371',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'nuga-gama',
      name: 'Nuga Gama - Cinnamon Grand',
      short_name: 'Nuga Gama',
      restaurant_name: 'Nuga Gama',
      cuisine: 'Traditional Sri Lankan Village Dining',
      branch: 'Cinnamon Grand',
      city: 'Galle Road, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9172,
      lon: 79.8488,
      phone: '+94 11 249 7369',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'shanmugas-wellawatte',
      name: 'Shanmugas Restaurant',
      short_name: 'Shanmugas',
      restaurant_name: 'Shanmugas',
      cuisine: 'South Indian Vegetarian',
      branch: 'Wellawatte',
      city: 'Ramakrishna Rd, Wellawatte, Colombo 06',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8785,
      lon: 79.8601,
      phone: '+94 11 236 1384',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'green-cabin-colombo',
      name: 'Green Cabin Restaurant',
      short_name: 'Green Cabin',
      restaurant_name: 'Green Cabin',
      cuisine: 'Traditional Sri Lankan & Bakery',
      branch: 'Kollupitiya',
      city: 'Galle Road, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8970,
      lon: 79.8565,
      phone: '+94 11 258 8811',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'raja-bojun',
      name: 'Raja Bojun',
      short_name: 'Raja Bojun',
      restaurant_name: 'Raja Bojun',
      cuisine: 'Authentic Sri Lankan Buffet',
      branch: 'Liberty Arcade',
      city: 'R.A. De Mel Mw, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9038,
      lon: 79.8530,
      phone: '+94 11 471 6171',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'galle-face-sea-spray',
      name: 'Sea Spray - The Galle Face Hotel',
      short_name: 'Sea Spray Galle Face',
      restaurant_name: 'Sea Spray',
      cuisine: 'Oceanfront Seafood & Grill',
      branch: 'Galle Face Hotel',
      city: 'Galle Road, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9205,
      lon: 79.8448,
      phone: '+94 11 254 1010',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'pilawoos-kollupitiya',
      name: 'Hotel de Pilawoos',
      short_name: 'Pilawoos Kollupitiya',
      restaurant_name: 'Hotel de Pilawoos',
      cuisine: 'Sri Lankan Street Food & Kottu',
      branch: 'Kollupitiya',
      city: 'Galle Road, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9080,
      lon: 79.8510,
      phone: '+94 11 257 4333',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'the-gallery-cafe',
      name: 'The Gallery Café (Paradise Road)',
      short_name: 'The Gallery Café',
      restaurant_name: 'The Gallery Café',
      cuisine: 'Contemporary Fusion & Desserts',
      branch: 'Bambalapitiya',
      city: 'Alfred House Rd, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8988,
      lon: 79.8550,
      phone: '+94 11 258 2162',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'kaema-sutra-shangrila',
      name: 'Kaema Sutra - Shangri-La Colombo',
      short_name: 'Kaema Sutra',
      restaurant_name: 'Kaema Sutra',
      cuisine: 'Modern Creative Sri Lankan',
      branch: 'Shangri-La Hotel',
      city: 'One Galle Face, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9272,
      lon: 79.8442,
      phone: '+94 11 788 8288',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'monsoon-colombo',
      name: 'Monsoon Colombo',
      short_name: 'Monsoon Colombo',
      restaurant_name: 'Monsoon',
      cuisine: 'Southeast Asian Street Food',
      branch: 'Park Street Mews',
      city: 'Park Street Mews, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9185,
      lon: 79.8580,
      phone: '+94 11 230 4333',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'bavarian-german-restaurant',
      name: 'Bavarian German Restaurant',
      short_name: 'Bavarian Colombo',
      restaurant_name: 'Bavarian German Restaurant',
      cuisine: 'European & German Grill',
      branch: 'Galle Face Terrace',
      city: 'Galle Face Terrace, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9200,
      lon: 79.8475,
      phone: '+94 11 242 2233',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'graze-kitchen-hilton',
      name: 'Graze Kitchen - Hilton Colombo',
      short_name: 'Graze Kitchen',
      restaurant_name: 'Graze Kitchen',
      cuisine: 'International Live Stations & Buffet',
      branch: 'Hilton Colombo',
      city: 'Sir Chittampalam A Gardiner Mw, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9320,
      lon: 79.8465,
      phone: '+94 11 249 2492',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'dinemore-thurstan',
      name: 'Dinemore - Thurstan Road',
      short_name: 'Dinemore Thurstan',
      restaurant_name: 'Dinemore',
      cuisine: 'Submarines, Grill & Fast Casual',
      branch: 'Thurstan Road',
      city: 'Thurstan Rd, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9040,
      lon: 79.8585,
      phone: '+94 11 255 6000',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'chola-authentic-indian',
      name: 'Chola Authentic Indian Restaurant',
      short_name: 'Chola Restaurant',
      restaurant_name: 'Chola',
      cuisine: 'North & South Indian Cuisine',
      branch: 'Wellawatte',
      city: 'Lily Ave, Wellawatte, Colombo 06',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8770,
      lon: 79.8595,
      phone: '+94 11 436 4364',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'the-kandy-house',
      name: 'The Kandy House Restaurant',
      short_name: 'The Kandy House',
      restaurant_name: 'The Kandy House',
      cuisine: 'Gourmet Fusion & Fine Dining',
      branch: 'Amunugama',
      city: 'Amunugama, Gunnepana, Kandy',
      district: 'Kandy',
      province: 'Central',
      lat: 7.3080,
      lon: 80.6720,
      phone: '+94 81 492 1394',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'slightly-chilled-kandy',
      name: 'Slightly Chilled Lounge & Restaurant',
      short_name: 'Slightly Chilled Kandy',
      restaurant_name: 'Slightly Chilled Lounge',
      cuisine: 'Asian, Continental & Lake View Dining',
      branch: 'Kandy Lake',
      city: 'Anagarika Dharmapala Mw, Kandy',
      district: 'Kandy',
      province: 'Central',
      lat: 7.2925,
      lon: 80.6410,
      phone: '+94 81 223 8238',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'pedlars-inn-galle',
      name: "Pedlar's Inn Café & Restaurant",
      short_name: "Pedlar's Inn Galle",
      restaurant_name: "Pedlar's Inn Café",
      cuisine: 'Italian, Continental & Gelato',
      branch: 'Galle Fort',
      city: 'Pedlar St, Galle Fort, Galle',
      district: 'Galle',
      province: 'Southern',
      lat: 6.0270,
      lon: 80.2175,
      phone: '+94 91 222 5333',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'a-minute-by-tuk-tuk',
      name: 'A Minute by Tuk Tuk',
      short_name: 'A Minute by Tuk Tuk',
      restaurant_name: 'A Minute by Tuk Tuk',
      cuisine: 'Sri Lankan Fusion & Seafood',
      branch: 'Dutch Hospital Galle',
      city: 'Old Dutch Hospital, Galle Fort, Galle',
      district: 'Galle',
      province: 'Southern',
      lat: 6.0260,
      lon: 80.2185,
      phone: '+94 91 224 4550',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'lords-restaurant-negombo',
      name: 'Lords Restaurant Complex',
      short_name: 'Lords Negombo',
      restaurant_name: 'Lords Restaurant',
      cuisine: 'Seafood, Sri Lankan & International',
      branch: 'Porutota',
      city: 'Porutota Rd, Negombo',
      district: 'Gampaha',
      province: 'Western',
      lat: 7.2340,
      lon: 79.8420,
      phone: '+94 31 227 5000',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'black-pepper-colombo',
      name: 'Black Pepper Restaurant',
      short_name: 'Black Pepper',
      restaurant_name: 'Black Pepper',
      cuisine: 'Authentic Sri Lankan Crab & Spices',
      branch: 'Dutch Hospital Fort',
      city: 'Old Dutch Hospital, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9342,
      lon: 79.8440,
      phone: '+94 11 232 0544',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 't-lounge-dilmah',
      name: 't-Lounge by Dilmah',
      short_name: 'Dilmah t-Lounge',
      restaurant_name: 't-Lounge by Dilmah',
      cuisine: 'Gourmet Tea, Crepes & High Tea',
      branch: 'Chatham Street',
      city: 'Chatham St, Fort, Colombo 01',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9338,
      lon: 79.8442,
      phone: '+94 11 244 7168',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'sultans-biryani-colombo',
      name: "Sultan's Biryani & Grill",
      short_name: "Sultan's Biryani",
      restaurant_name: "Sultan's Biryani",
      cuisine: 'Biryani, Tandoor & Middle Eastern',
      branch: 'Bambalapitiya',
      city: 'Marine Drive, Colombo 04',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8890,
      lon: 79.8545,
      phone: '+94 11 250 8800',
      slug: 'restaurant',
      color: '#f59e0b'
    },
    {
      id: 'manhattan-fish-market',
      name: 'The Manhattan Fish Market',
      short_name: 'Manhattan Fish Market',
      restaurant_name: 'The Manhattan Fish Market',
      cuisine: 'American Style Seafood & Platters',
      branch: 'Kollupitiya',
      city: 'Deal Place, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9042,
      lon: 79.8535,
      phone: '+94 11 237 0044',
      slug: 'restaurant',
      color: '#f59e0b'
    }
  ];

  // Major Supermarkets in Sri Lanka (Cargills Food City, Keells Super, Arpico Supercentre, SPAR, GLOMARK, Laugfs)
  const SRI_LANKA_SUPERMARKETS_DATA = [
    {
      id: 'keells-union-place',
      name: 'Keells Super - Union Place',
      short_name: 'Keells Union Place',
      supermarket_name: 'Keells Super',
      chain: 'Keells Super',
      branch: 'Union Place',
      city: 'Union Place, Slave Island, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9180,
      lon: 79.8580,
      phone: '+94 11 230 3500',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'cargills-food-city-staples',
      name: 'Cargills Food City - Staples Street',
      short_name: 'Cargills Staples St',
      supermarket_name: 'Cargills Food City',
      chain: 'Cargills Food City',
      branch: 'Staples Street',
      city: 'Staples Street, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9192,
      lon: 79.8596,
      phone: '+94 11 242 7777',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'arpico-supercentre-hyde-park',
      name: 'Arpico Supercentre - Hyde Park Corner',
      short_name: 'Arpico Hyde Park',
      supermarket_name: 'Arpico Supercentre',
      chain: 'Arpico Supercentre',
      branch: 'Hyde Park Corner',
      city: 'Hyde Park Corner, Colombo 02',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9188,
      lon: 79.8590,
      phone: '+94 11 268 7654',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'spar-thalawathugoda',
      name: 'SPAR Supermarket - Thalawathugoda',
      short_name: 'SPAR Thalawathugoda',
      supermarket_name: 'SPAR Supermarket',
      chain: 'SPAR Supermarket',
      branch: 'Thalawathugoda',
      city: 'Pannipitiya Road, Thalawathugoda',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8770,
      lon: 79.9320,
      phone: '+94 11 277 5600',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'glomark-kottawa',
      name: 'Softlogic GLOMARK - Kottawa',
      short_name: 'GLOMARK Kottawa',
      supermarket_name: 'Softlogic GLOMARK',
      chain: 'Softlogic GLOMARK',
      branch: 'Kottawa',
      city: 'High Level Road, Kottawa',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8450,
      lon: 79.9650,
      phone: '+94 11 512 8000',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'cargills-food-city-majestic',
      name: 'Cargills Food City - Majestic City',
      short_name: 'Cargills Majestic City',
      supermarket_name: 'Cargills Food City',
      chain: 'Cargills Food City',
      branch: 'Bambalapitiya',
      city: 'Station Road, Bambalapitiya, Colombo 04',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8940,
      lon: 79.8548,
      phone: '+94 11 258 1106',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'keells-crescat',
      name: 'Keells Super - Crescat Boulevard',
      short_name: 'Keells Crescat',
      supermarket_name: 'Keells Super',
      chain: 'Keells Super',
      branch: 'Crescat Boulevard',
      city: 'Galle Road, Kollupitiya, Colombo 03',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9184,
      lon: 79.8492,
      phone: '+94 11 230 3500',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'arpico-supercentre-battaramulla',
      name: 'Arpico Supercentre - Battaramulla',
      short_name: 'Arpico Battaramulla',
      supermarket_name: 'Arpico Supercentre',
      chain: 'Arpico Supercentre',
      branch: 'Battaramulla',
      city: 'Main Street, Battaramulla',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8980,
      lon: 79.9190,
      phone: '+94 11 287 4500',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'laugfs-rajagiriya',
      name: 'Laugfs Supermarket - Rajagiriya',
      short_name: 'Laugfs Rajagiriya',
      supermarket_name: 'Laugfs Supermarket',
      chain: 'Laugfs Supermarket',
      branch: 'Rajagiriya',
      city: 'Kotte Road, Rajagiriya',
      district: 'Colombo',
      province: 'Western',
      lat: 6.9085,
      lon: 79.8935,
      phone: '+94 11 556 6222',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'spar-kalubowila',
      name: 'SPAR Supermarket - Kalubowila',
      short_name: 'SPAR Kalubowila',
      supermarket_name: 'SPAR Supermarket',
      chain: 'SPAR Supermarket',
      branch: 'Kalubowila',
      city: 'Hospital Road, Kalubowila, Dehiwala',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8745,
      lon: 79.8810,
      phone: '+94 11 276 4500',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'cargills-food-city-nawala',
      name: 'Cargills Food City - Nawala Road',
      short_name: 'Cargills Nawala',
      supermarket_name: 'Cargills Food City',
      chain: 'Cargills Food City',
      branch: 'Nawala',
      city: 'Nawala Road, Nugegoda',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8885,
      lon: 79.8890,
      phone: '+94 11 280 5544',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'glomark-nawala',
      name: 'Softlogic GLOMARK - Nawala',
      short_name: 'GLOMARK Nawala',
      supermarket_name: 'Softlogic GLOMARK',
      chain: 'Softlogic GLOMARK',
      branch: 'Nawala',
      city: 'Nawala Road, Rajagiriya',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8995,
      lon: 79.8910,
      phone: '+94 11 512 8100',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'keells-havelock-road',
      name: 'Keells Super - Havelock Road',
      short_name: 'Keells Havelock Rd',
      supermarket_name: 'Keells Super',
      chain: 'Keells Super',
      branch: 'Havelock Road',
      city: 'Havelock Road, Colombo 05',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8830,
      lon: 79.8665,
      phone: '+94 11 259 8765',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'arpico-daily-dehiwala',
      name: 'Arpico Daily - Dehiwala',
      short_name: 'Arpico Dehiwala',
      supermarket_name: 'Arpico Daily',
      chain: 'Arpico Supercentre',
      branch: 'Dehiwala',
      city: 'Galle Road, Dehiwala',
      district: 'Colombo',
      province: 'Western',
      lat: 6.8520,
      lon: 79.8640,
      phone: '+94 11 273 6677',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'laugfs-moratuwa',
      name: 'Laugfs Supermarket - Moratuwa',
      short_name: 'Laugfs Moratuwa',
      supermarket_name: 'Laugfs Supermarket',
      chain: 'Laugfs Supermarket',
      branch: 'Moratuwa',
      city: 'Galle Road, Rawathawatte, Moratuwa',
      district: 'Colombo',
      province: 'Western',
      lat: 6.7860,
      lon: 79.8850,
      phone: '+94 11 556 6333',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'keells-kandy-kcc',
      name: 'Keells Super - Kandy City Centre',
      short_name: 'Keells KCC Kandy',
      supermarket_name: 'Keells Super',
      chain: 'Keells Super',
      branch: 'Kandy City Centre',
      city: 'Kandy City Centre, Dalada Veediya, Kandy',
      district: 'Kandy',
      province: 'Central',
      lat: 7.2930,
      lon: 80.6355,
      phone: '+94 81 220 5400',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'cargills-food-city-kandy',
      name: 'Cargills Food City - Kandy',
      short_name: 'Cargills Kandy',
      supermarket_name: 'Cargills Food City',
      chain: 'Cargills Food City',
      branch: 'Dalada Veediya',
      city: 'Dalada Veediya, Kandy',
      district: 'Kandy',
      province: 'Central',
      lat: 7.2945,
      lon: 80.6370,
      phone: '+94 81 222 4321',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'arpico-supercentre-kandy',
      name: 'Arpico Supercentre - Kandy',
      short_name: 'Arpico Kandy',
      supermarket_name: 'Arpico Supercentre',
      chain: 'Arpico Supercentre',
      branch: 'Peradeniya Road',
      city: 'Peradeniya Road, Kandy',
      district: 'Kandy',
      province: 'Central',
      lat: 7.2840,
      lon: 80.6260,
      phone: '+94 81 223 8899',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'keells-galle-road',
      name: 'Keells Super - Galle City',
      short_name: 'Keells Galle',
      supermarket_name: 'Keells Super',
      chain: 'Keells Super',
      branch: 'Galle Main Road',
      city: 'Colombo Road, Kaluwella, Galle',
      district: 'Galle',
      province: 'Southern',
      lat: 6.0370,
      lon: 80.2160,
      phone: '+94 91 224 5600',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'cargills-food-city-galle',
      name: 'Cargills Food City - Galle',
      short_name: 'Cargills Galle',
      supermarket_name: 'Cargills Food City',
      chain: 'Cargills Food City',
      branch: 'Galle Fort Road',
      city: 'Main Street, Galle',
      district: 'Galle',
      province: 'Southern',
      lat: 6.0340,
      lon: 80.2175,
      phone: '+94 91 223 3456',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'arpico-supercentre-galle',
      name: 'Arpico Supercentre - Galle',
      short_name: 'Arpico Galle',
      supermarket_name: 'Arpico Supercentre',
      chain: 'Arpico Supercentre',
      branch: 'Karapitiya Road',
      city: 'Karapitiya Road, Galle',
      district: 'Galle',
      province: 'Southern',
      lat: 6.0520,
      lon: 80.2240,
      phone: '+94 91 222 7890',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'keells-negombo',
      name: 'Keells Super - Negombo',
      short_name: 'Keells Negombo',
      supermarket_name: 'Keells Super',
      chain: 'Keells Super',
      branch: 'Negombo',
      city: 'Main Street, Negombo',
      district: 'Gampaha',
      province: 'Western',
      lat: 7.2180,
      lon: 79.8450,
      phone: '+94 31 223 1234',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'cargills-food-city-negombo',
      name: 'Cargills Food City - Negombo',
      short_name: 'Cargills Negombo',
      supermarket_name: 'Cargills Food City',
      chain: 'Cargills Food City',
      branch: 'Negombo',
      city: 'Greens Road, Negombo',
      district: 'Gampaha',
      province: 'Western',
      lat: 7.2105,
      lon: 79.8390,
      phone: '+94 31 222 3456',
      slug: 'supermarket',
      color: '#10b981'
    },
    {
      id: 'arpico-supercentre-gampaha',
      name: 'Arpico Supercentre - Gampaha',
      short_name: 'Arpico Gampaha',
      supermarket_name: 'Arpico Supercentre',
      chain: 'Arpico Supercentre',
      branch: 'Gampaha',
      city: 'Ja-Ela Road, Gampaha',
      district: 'Gampaha',
      province: 'Western',
      lat: 7.0890,
      lon: 79.9920,
      phone: '+94 33 223 4567',
      slug: 'supermarket',
      color: '#10b981'
    }
  ];

  // Predefined Reference Coordinates (Primary in Sri Lanka)
  const REFERENCE_GPS_COORDINATES = {
    'hospital': { lat: 6.9197, lon: 79.8693, name: 'National Hospital of Sri Lanka (NHSL), Colombo' },
    'supermarket': { lat: 6.9180, lon: 79.8620, name: 'Cargills Food City / Keells Supermarket, Colombo' },
    'restaurant': { lat: 6.9115, lon: 79.8635, name: "Upali's by Nawaloka / Dining Colombo" },
    'bank': { lat: 6.9333, lon: 79.8430, name: 'Bank of Ceylon (BOC) / Commercial Bank Head Office' },
    'pharmacy': { lat: 6.9205, lon: 79.8665, name: 'State Pharmaceuticals Corporation (Osu Sala) Colombo' },
    'other': { lat: 6.8900, lon: 79.8700, name: 'Colombo Residential Area (Outside Venues)' }
  };

  const VENUE_METADATA = {
    'supermarket': { icon: 'fa-cart-shopping', color: '#10b981', label: 'Supermarket' },
    'restaurant': { icon: 'fa-utensils', color: '#f59e0b', label: 'Restaurant' },
    'bank': { icon: 'fa-building-columns', color: '#2563eb', label: 'Bank & ATM' },
    'hospital': { icon: 'fa-hospital', color: '#ef4444', label: 'Hospital' },
    'pharmacy': { icon: 'fa-prescription-bottle-medical', color: '#8b5cf6', label: 'Pharmacy' },
    'other': { icon: 'fa-earth-americas', color: '#6366f1', label: 'Outside Venues' }
  };

  // Leaflet Area Map State
  let areaMap = null;
  let userGpsMarker = null;
  let userAccuracyCircle = null;
  let venueMarkersGroup = null;
  let sriLankaHospitalsLayer = null;
  let sriLankaBanksLayer = null;
  let sriLankaRestaurantsLayer = null;
  let sriLankaSupermarketsLayer = null;
  let currentCoordinates = null;
  let isMapExpanded = false;
  let allHospitalsData = [...SRI_LANKA_HOSPITALS_DATA];
  let allBanksData = [...SRI_LANKA_BANKS_DATA];
  let allRestaurantsData = [...SRI_LANKA_RESTAURANTS_DATA];
  let allSupermarketsData = [...SRI_LANKA_SUPERMARKETS_DATA];
  let hospitalMarkersMap = {};
  let bankMarkersMap = {};
  let restaurantMarkersMap = {};
  let supermarketMarkersMap = {};

  // LocalStorage state
  let historyData = JSON.parse(localStorage.getItem('assistcomm_history') || '[]');
  let favoritesData = JSON.parse(localStorage.getItem('assistcomm_favorites') || '[]');

  // 1. Clock in Status Bar
  function updateClock() {
    if (!statusTime) return;
    const now = new Date();
    let hours = now.getHours();
    let minutes = now.getMinutes();
    const formatted = `${hours}:${minutes < 10 ? '0' : ''}${minutes}`;
    statusTime.textContent = formatted;
  }
  updateClock();
  setInterval(updateClock, 30000);

  // 2. Tab Navigation
  function switchTab(targetTab) {
    navButtons.forEach(b => {
      if (b.getAttribute('data-tab') === targetTab) {
        b.classList.add('active');
      } else {
        b.classList.remove('active');
      }
    });

    tabPanels.forEach(panel => {
      if (panel.id === `tab-${targetTab}`) {
        panel.classList.add('active');
      } else {
        panel.classList.remove('active');
      }
    });

    if (targetTab === 'home') {
      if (typeof backToFirstScreen === 'function') {
        backToFirstScreen();
      }
      setTimeout(() => {
        if (areaMap) areaMap.invalidateSize();
      }, 200);
    }
    if (targetTab === 'history') renderHistory();
    if (targetTab === 'favorites') renderFavorites();
  }

  navButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetTab = btn.getAttribute('data-tab');
      switchTab(targetTab);
    });
  });

  // 3. Open Billboard Modal with given message
  let currentActiveMsg = '';
  let currentActiveMsgSi = '';
  function displayMessageBillboard(text, iconClass = 'fa-comment-dots', textSi = '') {
    currentActiveMsg = text;
    currentActiveMsgSi = textSi;
    const billboardTextSi = document.getElementById('billboard-text-si');
    if (billboardTextSi) {
      if (textSi) {
        billboardTextSi.textContent = textSi;
        billboardTextSi.style.display = 'block';
      } else {
        billboardTextSi.textContent = '';
        billboardTextSi.style.display = 'none';
      }
    }
    if (billboardText) billboardText.textContent = text;
    if (billboardIcon) billboardIcon.className = `fa-solid ${iconClass} billboard-icon`;
    if (billboardCenter) billboardCenter.classList.remove('flipped');
    
    // Check if in favorites
    const isFav = favoritesData.some(f => f.text === text || (textSi && f.text.includes(textSi)));
    updateFavButtonUI(isFav);

    if (billboardModal) billboardModal.classList.add('open');

    // Add to history
    const historyEntry = textSi ? `${textSi} (${text})` : text;
    addToHistory(historyEntry, iconClass);
  }

  function closeBillboard() {
    if (billboardModal) billboardModal.classList.remove('open');
  }

  if (billboardBackBtn) {
    billboardBackBtn.addEventListener('click', closeBillboard);
  }

  if (billboardFlipBtn) {
    billboardFlipBtn.addEventListener('click', () => {
      if (billboardCenter) billboardCenter.classList.toggle('flipped');
      billboardFlipBtn.classList.toggle('active');
    });
  }

  // Text-To-Speech (TTS)
  function speakMessage(text) {
    if (!('speechSynthesis' in window)) {
      alert("Text-to-speech is not supported in this browser.");
      return;
    }
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = 0.95;
    utterance.pitch = 1.0;
    window.speechSynthesis.speak(utterance);
  }

  if (billboardSpeakBtn) {
    billboardSpeakBtn.addEventListener('click', () => {
      speakMessage(currentActiveMsg);
    });
  }

  function updateFavButtonUI(isFav) {
    if (!billboardFavBtn) return;
    if (isFav) {
      billboardFavBtn.innerHTML = '<i class="fa-solid fa-star" style="color: #f59e0b;"></i> Favorited';
    } else {
      billboardFavBtn.innerHTML = '<i class="fa-regular fa-star"></i> Favorite';
    }
  }

  if (billboardFavBtn) {
    billboardFavBtn.addEventListener('click', () => {
      toggleFavorite(currentActiveMsg, 'fa-comment');
    });
  }

  // 4. Bind Message Cards
  function bindMessageCardListeners() {
    const cards = document.querySelectorAll('.msg-action-card');
    cards.forEach(card => {
      card.onclick = (e) => {
        if (e.target.closest('.card-fav-star')) {
          e.stopPropagation();
          const text = card.getAttribute('data-msg') || '';
          toggleFavorite(text, card.getAttribute('data-icon') || 'fa-comment');
          return;
        }

        const msgEn = card.getAttribute('data-msg-en') || card.getAttribute('data-msg') || '';
        const msgSi = card.getAttribute('data-msg-si') || '';
        const icon = card.getAttribute('data-icon') || 'fa-comment-dots';
        displayMessageBillboard(msgEn, icon, msgSi);
      };
    });
  }
  bindMessageCardListeners();

  // Escape HTML helper for message templates
  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // Render Dual-Language Hospital Messages into Grid (No 1-10 numbers on cards)
  function renderHospitalMessages(messagesList) {
    const messagesGrid = document.getElementById('messages-grid');
    if (!messagesGrid || !Array.isArray(messagesList) || messagesList.length === 0) return;

    messagesGrid.innerHTML = messagesList.map((msg) => {
      const templateSi = msg.template_si || '';
      const templateEn = msg.template_en || msg.template || '';
      const fullMsg = templateSi ? `${templateSi} (${templateEn})` : templateEn;
      const icon = msg.icon || 'fa-comment-dots';

      return `
        <button class="msg-action-card dual-lang-card" role="listitem" type="button" 
                data-msg="${escapeHtml(fullMsg)}" 
                data-msg-si="${escapeHtml(templateSi)}" 
                data-msg-en="${escapeHtml(templateEn)}" 
                data-icon="${escapeHtml(icon)}" 
                aria-label="Display message: ${escapeHtml(templateSi)} - ${escapeHtml(templateEn)}">
          <div class="card-inner-dual">
            <div class="card-header-meta">
              <i class="fa-solid ${escapeHtml(icon)} card-icon-badge"></i>
            </div>
            <div class="card-dual-body">
              <div class="card-text-si">${escapeHtml(templateSi)}</div>
              <div class="card-text-en">${escapeHtml(templateEn)}</div>
            </div>
          </div>
          <div class="card-right-meta">
            <button class="card-fav-star" type="button" aria-label="Add to Favorites" title="Favorite">
              <i class="fa-regular fa-star"></i>
            </button>
            <i class="fa-solid fa-chevron-right card-arrow-icon" aria-hidden="true"></i>
          </div>
        </button>
      `;
    }).join('');

    bindMessageCardListeners();
  }


  let cachedBankCategories = {
    'bank-basic-comm': [
      { id: 1, template: "I am deaf.", template_en: "I am deaf.", template_si: "මම බිහිරි කෙනෙක්.", icon: "fa-ear-deaf", category: "Basic communication" },
      { id: 2, template: "I cannot speak.", template_en: "I cannot speak.", template_si: "මට කතා කරන්න බැහැ.", icon: "fa-comment-slash", category: "Basic communication" },
      { id: 3, template: "Please write down your message.", template_en: "Please write down your message.", template_si: "කරුණාකර ඔබේ පණිවිඩය ලියන්න.", icon: "fa-pen-to-square", category: "Basic communication" },
      { id: 4, template: "Please speak slowly and face me.", template_en: "Please speak slowly and face me.", template_si: "කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.", icon: "fa-eye", category: "Basic communication" },
      { id: 5, template: "Please wait a moment.", template_en: "Please wait a moment.", template_si: "කරුණාකර මොහොතක් රැඳී සිටින්න.", icon: "fa-clock", category: "Basic communication" },
      { id: 6, template: "Please repeat that.", template_en: "Please repeat that.", template_si: "කරුණාකර නැවත කියන්න.", icon: "fa-rotate-right", category: "Basic communication" },
      { id: 7, template: "I do not understand.", template_en: "I do not understand.", template_si: "මට තේරෙන්නේ නැහැ.", icon: "fa-circle-question", category: "Basic communication" }
    ],
    'bank-reception-queue': [
      { id: 1, template: "I need help.", template_en: "I need help.", template_si: "මට උදව්වක් අවශ්යයි.", icon: "fa-handshake-angle", category: "Reception and queue" },
      { id: 2, template: "Where is the customer service desk?", template_en: "Where is the customer service desk?", template_si: "ගනුදෙනුකරු සේවා මේසය කොහෙද?", icon: "fa-headset", category: "Reception and queue" },
      { id: 3, template: "Where do I get a queue token?", template_en: "Where do I get a queue token?", template_si: "පෝලිම් ටෝකන් අංකය ලබාගන්නේ කොහෙන්ද?", icon: "fa-ticket", category: "Reception and queue" },
      { id: 4, template: "Which counter should I go to?", template_en: "Which counter should I go to?", template_si: "මම යා යුත්තේ කුමන කවුන්ටරයට ද?", icon: "fa-arrow-right-to-bracket", category: "Reception and queue" },
      { id: 5, template: "How long is the waiting time?", template_en: "How long is the waiting time?", template_si: "බලා සිටිය යුතු කාලය කොපමණ ද?", icon: "fa-hourglass-half", category: "Reception and queue" },
      { id: 6, template: "Please tap my shoulder when it is my turn.", template_en: "Please tap my shoulder when it is my turn.", template_si: "මගේ වාරය පැමිණි විට කරුණාකර මගේ උරහිසට තට්ටු කරන්න.", icon: "fa-hand-pointer", category: "Reception and queue" },
      { id: 7, template: "Please let me know when my number is called.", template_en: "Please let me know when my number is called.", template_si: "මගේ අංකය කැඳවන විට කරුණාකර මට දන්වන්න.", icon: "fa-bullhorn", category: "Reception and queue" },
      { id: 8, template: "May I speak to the manager?", template_en: "May I speak to the manager?", template_si: "මට කළමනාකරු හමුවීමට පුළුවන් ද?", icon: "fa-user-tie", category: "Reception and queue" }
    ],
    'bank-open-account': [
      { id: 1, template: "I want to open a new account.", template_en: "I want to open a new account.", template_si: "මට නව ගිණුමක් විවෘත කිරීමට අවශ්යයි.", icon: "fa-user-plus", category: "Opening an account" },
      { id: 2, template: "I want to open a savings account.", template_en: "I want to open a savings account.", template_si: "මට ඉතිරිකිරීමේ ගිණුමක් විවෘත කිරීමට අවශ්යයි.", icon: "fa-piggy-bank", category: "Opening an account" },
      { id: 3, template: "I want to open a current account.", template_en: "I want to open a current account.", template_si: "මට ජංගම ගිණුමක් විවෘත කිරීමට අවශ්යයි.", icon: "fa-briefcase", category: "Opening an account" },
      { id: 4, template: "I want to open a fixed deposit.", template_en: "I want to open a fixed deposit.", template_si: "මට ස්ථාවර තැන්පතුවක් ආරම්භ කිරීමට අවශ්යයි.", icon: "fa-vault", category: "Opening an account" },
      { id: 5, template: "What documents do I need?", template_en: "What documents do I need?", template_si: "මට අවශ්ය ලේඛන මොනවාද?", icon: "fa-file-lines", category: "Opening an account" },
      { id: 6, template: "Here is my National Identity Card.", template_en: "Here is my National Identity Card.", template_si: "මෙන්න මගේ ජාතික හැඳුනුම්පත.", icon: "fa-id-card", category: "Opening an account" },
      { id: 7, template: "Here is my passport.", template_en: "Here is my passport.", template_si: "මෙන්න මගේ විදේශ ගමන් බලපත්රය.", icon: "fa-passport", category: "Opening an account" },
      { id: 8, template: "Here is my proof of address.", template_en: "Here is my proof of address.", template_si: "මෙන්න මගේ ලිපිනය තහවුරු කරන ලේඛනය.", icon: "fa-house-chimney", category: "Opening an account" },
      { id: 9, template: "What is the minimum balance required?", template_en: "What is the minimum balance required?", template_si: "අවශ්ය අවම ශේෂය කීයද?", icon: "fa-scale-balanced", category: "Opening an account" },
      { id: 10, template: "Is there a monthly fee?", template_en: "Is there a monthly fee?", template_si: "මාසික ගාස්තුවක් තියෙනවා ද?", icon: "fa-coins", category: "Opening an account" },
      { id: 11, template: "Where should I sign?", template_en: "Where should I sign?", template_si: "මම අත්සන් කළ යුත්තේ කොහෙද?", icon: "fa-signature", category: "Opening an account" },
      { id: 12, template: "Can I have a copy of the form?", template_en: "Can I have a copy of the form?", template_si: "ෆෝරමයේ පිටපතක් ලබාගන්න පුළුවන් ද?", icon: "fa-copy", category: "Opening an account" }
    ],
    'bank-deposits-withdrawals': [
      { id: 1, template: "I want to deposit money.", template_en: "I want to deposit money.", template_si: "මට මුදල් තැන්පත් කිරීමට අවශ්යයි.", icon: "fa-money-bill-wave", category: "Deposits and withdrawals" },
      { id: 2, template: "I want to withdraw money.", template_en: "I want to withdraw money.", template_si: "මට මුදල් ආපසු ගැනීමට අවශ්යයි.", icon: "fa-hand-holding-dollar", category: "Deposits and withdrawals" },
      { id: 3, template: "I want to deposit a cheque.", template_en: "I want to deposit a cheque.", template_si: "මට චෙක්පතක් තැන්පත් කිරීමට අවශ්යයි.", icon: "fa-money-check", category: "Deposits and withdrawals" },
      { id: 4, template: "I want to cash a cheque.", template_en: "I want to cash a cheque.", template_si: "මට චෙක්පතක් මුදල් බවට හරවා ගැනීම අවශ්යයි.", icon: "fa-money-check-dollar", category: "Deposits and withdrawals" },
      { id: 5, template: "How much can I withdraw today?", template_en: "How much can I withdraw today?", template_si: "අද මට උපරිම කොපමණ මුදලක් ආපසු ගත හැකිද?", icon: "fa-calculator", category: "Deposits and withdrawals" },
      { id: 6, template: "Please give me small notes.", template_en: "Please give me small notes.", template_si: "කරුණාකර කුඩා නෝට්ටු දෙන්න.", icon: "fa-money-bills", category: "Deposits and withdrawals" },
      { id: 7, template: "Please count the money in front of me.", template_en: "Please count the money in front of me.", template_si: "කරුණාකර මා ඉදිරියේ මුදල් ගණන් කරන්න.", icon: "fa-eye", category: "Deposits and withdrawals" },
      { id: 8, template: "Here is the deposit slip.", template_en: "Here is the deposit slip.", template_si: "මෙන්න තැන්පතු පත්රිකාව.", icon: "fa-file-invoice", category: "Deposits and withdrawals" },
      { id: 9, template: "Where can I get a deposit slip?", template_en: "Where can I get a deposit slip?", template_si: "තැන්පතු පත්රිකාවක් ලබාගන්නේ කොහෙන්ද?", icon: "fa-circle-question", category: "Deposits and withdrawals" },
      { id: 10, template: "Please give me a receipt.", template_en: "Please give me a receipt.", template_si: "කරුණාකර රිසිට්පතක් දෙන්න.", icon: "fa-receipt", category: "Deposits and withdrawals" },
      { id: 11, template: "What is my account balance?", template_en: "What is my account balance?", template_si: "මගේ ගිණුම් ශේෂය කීයද?", icon: "fa-scale-balanced", category: "Deposits and withdrawals" },
      { id: 12, template: "Please update my passbook.", template_en: "Please update my passbook.", template_si: "කරුණාකර මගේ බැංකු පොත යාවත්කාලීන කරන්න.", icon: "fa-book", category: "Deposits and withdrawals" }
    ],
    'bank-cards-atm': [
      { id: 1, template: "I want to apply for a debit card.", template_en: "I want to apply for a debit card.", template_si: "මට ඩෙබිට් කාඩ්පතක් සඳහා අයදුම් කිරීමට අවශ්යයි.", icon: "fa-credit-card", category: "Cards and ATM" },
      { id: 2, template: "I want to apply for a credit card.", template_en: "I want to apply for a credit card.", template_si: "මට ක්රෙඩිට් කාඩ්පතක් සඳහා අයදුම් කිරීමට අවශ්යයි.", icon: "fa-credit-card", category: "Cards and ATM" },
      { id: 3, template: "I have lost my card.", template_en: "I have lost my card.", template_si: "මගේ කාඩ්පත නැති වුණා.", icon: "fa-circle-exclamation", category: "Cards and ATM" },
      { id: 4, template: "My card was stolen.", template_en: "My card was stolen.", template_si: "මගේ කාඩ්පත සොරකම් වුණා.", icon: "fa-shield-halved", category: "Cards and ATM" },
      { id: 5, template: "Please block my card.", template_en: "Please block my card.", template_si: "කරුණාකර මගේ කාඩ්පත අවහිර කරන්න.", icon: "fa-ban", category: "Cards and ATM" },
      { id: 6, template: "My card is not working.", template_en: "My card is not working.", template_si: "මගේ කාඩ්පත ක්රියා කරන්නේ නැහැ.", icon: "fa-triangle-exclamation", category: "Cards and ATM" },
      { id: 7, template: "The ATM kept my card.", template_en: "The ATM kept my card.", template_si: "ATM යන්ත්රය මගේ කාඩ්පත රඳවා ගත්තා.", icon: "fa-box-archive", category: "Cards and ATM" },
      { id: 8, template: "The ATM did not give me the cash.", template_en: "The ATM did not give me the cash.", template_si: "ATM යන්ත්රය මට මුදල් දුන්නේ නැහැ.", icon: "fa-money-bill-circle-xmark", category: "Cards and ATM" },
      { id: 9, template: "I forgot my PIN.", template_en: "I forgot my PIN.", template_si: "මට මගේ PIN අංකය අමතක වුණා.", icon: "fa-key", category: "Cards and ATM" },
      { id: 10, template: "I want to change my PIN.", template_en: "I want to change my PIN.", template_si: "මට මගේ PIN අංකය වෙනස් කිරීමට අවශ්යයි.", icon: "fa-arrows-rotate", category: "Cards and ATM" },
      { id: 11, template: "Where is the ATM?", template_en: "Where is the ATM?", template_si: "ATM යන්ත්රය කොහෙද?", icon: "fa-map-pin", category: "Cards and ATM" },
      { id: 12, template: "I want to activate my card.", template_en: "I want to activate my card.", template_si: "මට මගේ කාඩ්පත සක්රිය කිරීමට අවශ්යයි.", icon: "fa-circle-check", category: "Cards and ATM" }
    ],
    'bank-loans': [
      { id: 1, template: "I want to apply for a loan.", template_en: "I want to apply for a loan.", template_si: "මට ණයක් සඳහා අයදුම් කිරීමට අවශ්යයි.", icon: "fa-file-signature", category: "Loans" },
      { id: 2, template: "I am interested in a personal loan.", template_en: "I am interested in a personal loan.", template_si: "මට පුද්ගලික ණයක් ගැන උනන්දුවක් තියෙනවා.", icon: "fa-user", category: "Loans" },
      { id: 3, template: "I am interested in a housing loan.", template_en: "I am interested in a housing loan.", template_si: "මට නිවාස ණයක් ගැන උනන්දුවක් තියෙනවා.", icon: "fa-house", category: "Loans" },
      { id: 4, template: "I am interested in a vehicle loan.", template_en: "I am interested in a vehicle loan.", template_si: "මට වාහන ණයක් ගැන උනන්දුවක් තියෙනවා.", icon: "fa-car", category: "Loans" },
      { id: 5, template: "What is the interest rate?", template_en: "What is the interest rate?", template_si: "පොලී අනුපාතය කීයද?", icon: "fa-percent", category: "Loans" },
      { id: 6, template: "What is the loan period?", template_en: "What is the loan period?", template_si: "ණය කාලය කොපමණද?", icon: "fa-calendar-days", category: "Loans" },
      { id: 7, template: "What is the monthly installment?", template_en: "What is the monthly installment?", template_si: "මාසික වාරිකය කීයද?", icon: "fa-calendar-check", category: "Loans" },
      { id: 8, template: "What documents are required for the loan?", template_en: "What documents are required for the loan?", template_si: "ණය සඳහා අවශ්ය ලේඛන මොනවාද?", icon: "fa-folder-open", category: "Loans" },
      { id: 9, template: "Do I need a guarantor?", template_en: "Do I need a guarantor?", template_si: "මට ඇපකරුවෙකු අවශ්යයි ද?", icon: "fa-user-group", category: "Loans" },
      { id: 10, template: "How long will the approval take?", template_en: "How long will the approval take?", template_si: "අනුමැතිය ලැබීමට කොපමණ කාලයක් ගතවේද?", icon: "fa-clock", category: "Loans" },
      { id: 11, template: "I want to settle my loan.", template_en: "I want to settle my loan.", template_si: "මට මගේ ණය නිරවුල් කිරීමට අවශ්යයි.", icon: "fa-circle-check", category: "Loans" },
      { id: 12, template: "Can I get a loan statement?", template_en: "Can I get a loan statement?", template_si: "මට ණය ප්රකාශයක් ලබාගත හැකිද?", icon: "fa-file-invoice-dollar", category: "Loans" }
    ],
    'bank-transfers-payments': [
      { id: 1, template: "I want to transfer money.", template_en: "I want to transfer money.", template_si: "මට මුදල් මාරු කිරීමට අවශ්යයි.", icon: "fa-arrow-right-arrow-left", category: "Transfers and payments" },
      { id: 2, template: "I want to transfer to another bank.", template_en: "I want to transfer to another bank.", template_si: "මට වෙනත් බැංකුවකට මුදල් මාරු කිරීමට අවශ්යයි.", icon: "fa-building-columns", category: "Transfers and payments" },
      { id: 3, template: "Here are the recipient's account details.", template_en: "Here are the recipient's account details.", template_si: "මෙන්න ලබන්නාගේ ගිණුම් විස්තර.", icon: "fa-user-tag", category: "Transfers and payments" },
      { id: 4, template: "Is there a transfer fee?", template_en: "Is there a transfer fee?", template_si: "මාරු කිරීමේ ගාස්තුවක් තියෙනවා ද?", icon: "fa-coins", category: "Transfers and payments" },
      { id: 5, template: "How long will the transfer take?", template_en: "How long will the transfer take?", template_si: "මාරු කිරීමට කොපමණ කාලයක් ගතවේද?", icon: "fa-hourglass-half", category: "Transfers and payments" },
      { id: 6, template: "I want to pay a utility bill.", template_en: "I want to pay a utility bill.", template_si: "මට උපයෝගිතා බිලක් ගෙවීමට අවශ්යයි.", icon: "fa-file-invoice", category: "Transfers and payments" },
      { id: 7, template: "I want to pay my credit card bill.", template_en: "I want to pay my credit card bill.", template_si: "මට මගේ ක්රෙඩිට් කාඩ්පත් බිල ගෙවීමට අවශ්යයි.", icon: "fa-credit-card", category: "Transfers and payments" },
      { id: 8, template: "I want to send money abroad.", template_en: "I want to send money abroad.", template_si: "මට විදේශයකට මුදල් යැවීමට අවශ්යයි.", icon: "fa-earth-americas", category: "Transfers and payments" },
      { id: 9, template: "I want to receive money from abroad.", template_en: "I want to receive money from abroad.", template_si: "මට විදේශයකින් මුදල් ලබාගැනීමට අවශ්යයි.", icon: "fa-globe", category: "Transfers and payments" },
      { id: 10, template: "I want to exchange foreign currency.", template_en: "I want to exchange foreign currency.", template_si: "මට විදේශ මුදල් මාරු කරගැනීමට අවශ්යයි.", icon: "fa-money-bill-transfer", category: "Transfers and payments" }
    ],
    'bank-account-services': [
      { id: 1, template: "I need a bank statement.", template_en: "I need a bank statement.", template_si: "මට ගිණුම් ප්රකාශයක් අවශ්යයි.", icon: "fa-file-lines", category: "Account services and problems" },
      { id: 2, template: "I need a statement for the last three months.", template_en: "I need a statement for the last three months.", template_si: "මට පසුගිය මාස තුනේ ගිණුම් ප්රකාශයක් අවශ්යයි.", icon: "fa-calendar-week", category: "Account services and problems" },
      { id: 3, template: "I want to update my phone number.", template_en: "I want to update my phone number.", template_si: "මට මගේ දුරකථන අංකය යාවත්කාලීන කිරීමට අවශ්යයි.", icon: "fa-phone", category: "Account services and problems" },
      { id: 4, template: "I want to update my address.", template_en: "I want to update my address.", template_si: "මට මගේ ලිපිනය යාවත්කාලීන කිරීමට අවශ්යයි.", icon: "fa-location-dot", category: "Account services and problems" },
      { id: 5, template: "I want to register for online banking.", template_en: "I want to register for online banking.", template_si: "මට අන්තර්ජාල බැංකුකරණය සඳහා ලියාපදිංචි වීමට අවශ්යයි.", icon: "fa-laptop", category: "Account services and problems" },
      { id: 6, template: "I want to set up mobile banking.", template_en: "I want to set up mobile banking.", template_si: "මට ජංගම බැංකුකරණය ස්ථාපිත කිරීමට අවශ්යයි.", icon: "fa-mobile-screen", category: "Account services and problems" },
      { id: 7, template: "I forgot my online banking password.", template_en: "I forgot my online banking password.", template_si: "මට මගේ අන්තර්ජාල බැංකු මුරපදය අමතක වුණා.", icon: "fa-key", category: "Account services and problems" },
      { id: 8, template: "I am not receiving SMS alerts.", template_en: "I am not receiving SMS alerts.", template_si: "මට SMS දැනුම්දීම් ලැබෙන්නේ නැහැ.", icon: "fa-comment-sms", category: "Account services and problems" },
      { id: 9, template: "There is a mistake in my account.", template_en: "There is a mistake in my account.", template_si: "මගේ ගිණුමේ වැරැද්දක් තියෙනවා.", icon: "fa-triangle-exclamation", category: "Account services and problems" },
      { id: 10, template: "Money was deducted from my account by mistake.", template_en: "Money was deducted from my account by mistake.", template_si: "මගේ ගිණුමෙන් වැරදීමකින් මුදල් අඩු වී තියෙනවා.", icon: "fa-circle-minus", category: "Account services and problems" },
      { id: 11, template: "I want to make a complaint.", template_en: "I want to make a complaint.", template_si: "මට පැමිණිල්ලක් ඉදිරිපත් කිරීමට අවශ්යයි.", icon: "fa-bullhorn", category: "Account services and problems" },
      { id: 12, template: "I want to close my account.", template_en: "I want to close my account.", template_si: "මට මගේ ගිණුම වසා දැමීමට අවශ්යයි.", icon: "fa-rectangle-xmark", category: "Account services and problems" }
    ],
    'bank-security-fraud': [
      { id: 1, template: "I think someone has accessed my account without permission.", template_en: "I think someone has accessed my account without permission.", template_si: "මගේ ගිණුමට අවසරයකින් තොරව කවුරුහරි ඇතුළු වී ඇති බව මට හැඟෙනවා.", icon: "fa-user-secret", category: "Security and fraud" },
      { id: 2, template: "I received a suspicious message or call.", template_en: "I received a suspicious message or call.", template_si: "මට සැක සහිත පණිවිඩයක් හෝ ඇමතුමක් ලැබුණා.", icon: "fa-triangle-exclamation", category: "Security and fraud" },
      { id: 3, template: "I did not make this transaction.", template_en: "I did not make this transaction.", template_si: "මම මෙම ගනුදෙනුව කළේ නැහැ.", icon: "fa-shield-halved", category: "Security and fraud" },
      { id: 4, template: "Please freeze my account.", template_en: "Please freeze my account.", template_si: "කරුණාකර මගේ ගිණුම අත්හිටුවන්න.", icon: "fa-snowflake", category: "Security and fraud" },
      { id: 5, template: "I want to change my password.", template_en: "I want to change my password.", template_si: "මට මගේ මුරපදය වෙනස් කිරීමට අවශ්යයි.", icon: "fa-lock", category: "Security and fraud" },
      { id: 6, template: "Please do not share my details with anyone.", template_en: "Please do not share my details with anyone.", template_si: "කරුණාකර මගේ තොරතුරු කිසිවෙකු සමඟ බෙදා නොගන්න.", icon: "fa-user-lock", category: "Security and fraud" }
    ],
    'bank-closing-courtesy': [
      { id: 1, template: "Can you explain this in writing?", template_en: "Can you explain this in writing?", template_si: "මෙය ලියා පැහැදිලි කරන්න පුළුවන් ද?", icon: "fa-pen-to-square", category: "Closing and courtesy" },
      { id: 2, template: "Please write down the amount.", template_en: "Please write down the amount.", template_si: "කරුණාකර මුදල ලියන්න.", icon: "fa-pen", category: "Closing and courtesy" },
      { id: 3, template: "Is a sign language interpreter available?", template_en: "Is a sign language interpreter available?", template_si: "සංඥා භාෂා පරිවර්තකයෙකු ඉන්නවාද?", icon: "fa-hands-asl-interpreting", category: "Closing and courtesy" },
      { id: 4, template: "May I bring someone to help me?", template_en: "May I bring someone to help me?", template_si: "මට උදව් කිරීමට කෙනෙකු රැගෙන එන්න පුළුවන් ද?", icon: "fa-person-circle-question", category: "Closing and courtesy" },
      { id: 5, template: "Is everything complete?", template_en: "Is everything complete?", template_si: "සියල්ල අවසන් ද?", icon: "fa-circle-check", category: "Closing and courtesy" },
      { id: 6, template: "Thank you for your help.", template_en: "Thank you for your help.", template_si: "ඔබේ උදව්වට ස්තූතියි.", icon: "fa-handshake", category: "Closing and courtesy" }
    ]
  };

  const HOSPITAL_CATEGORY_METADATA = {
    'basic-comm': {
      titleSi: '1. මූලික සන්නිවේදනය',
      titleEn: 'Basic communication',
      label: '1. මූලික සන්නිවේදනය / Basic communication',
      icon: 'fa-comments',
      buttonId: 'btn-cat-basic-comm',
      badgeId: 'cat-badge-basic-comm'
    },
    'reception': {
      titleSi: '2. පිළිගැනීම සහ ලියාපදිංචිය',
      titleEn: 'Reception and registration',
      label: '2. පිළිගැනීම සහ ලියාපදිංචිය / Reception and registration',
      icon: 'fa-clipboard-user',
      buttonId: 'btn-cat-reception',
      badgeId: 'cat-badge-reception'
    },
    'directions': {
      titleSi: '3. දිශාවන්',
      titleEn: 'Directions',
      label: '3. දිශාවන් / Directions',
      icon: 'fa-diamond-turn-right',
      buttonId: 'btn-cat-directions',
      badgeId: 'cat-badge-directions'
    },
    'symptoms': {
      titleSi: '4. රෝග ලක්ෂණ',
      titleEn: 'Symptoms',
      label: '4. රෝග ලක්ෂණ / Symptoms',
      icon: 'fa-heart-pulse',
      buttonId: 'btn-cat-symptoms',
      badgeId: 'cat-badge-symptoms'
    },
    'emergency': {
      titleSi: '5. හදිසි අවස්ථාව',
      titleEn: 'Emergency',
      label: '5. හදිසි අවස්ථාව / Emergency',
      icon: 'fa-truck-medical',
      buttonId: 'btn-cat-emergency',
      badgeId: 'cat-badge-emergency'
    },
    'medical-history': {
      titleSi: '6. වෛද්ය ඉතිහාසය',
      titleEn: 'Medical history',
      label: '6. වෛද්ය ඉතිහාසය / Medical history',
      icon: 'fa-file-waveform',
      buttonId: 'btn-cat-medical-history',
      badgeId: 'cat-badge-medical-history'
    },
    'doctor-consultation': {
      titleSi: '7. වෛද්ය උපදේශනය',
      titleEn: 'Doctor consultation',
      label: '7. වෛද්ය උපදේශනය / Doctor consultation',
      icon: 'fa-user-doctor',
      buttonId: 'btn-cat-doctor-consultation',
      badgeId: 'cat-badge-doctor-consultation'
    },
    'procedures-comfort': {
      titleSi: '8. ක්රියාපටිපාටි සහ පහසුව',
      titleEn: 'Procedures and comfort',
      label: '8. ක්රියාපටිපාටි සහ පහසුව / Procedures and comfort',
      icon: 'fa-hand-holding-heart',
      buttonId: 'btn-cat-procedures-comfort',
      badgeId: 'cat-badge-procedures-comfort'
    },
    'pharmacy-billing': {
      titleSi: '9. ඖෂධ ශාලාව, බිල්පත් කිරීම සහ බැහැර කිරීම',
      titleEn: 'Pharmacy, billing and discharge',
      label: '9. ඖෂධ ශාලාව, බිල්පත් කිරීම සහ බැහැර කිරීම / Pharmacy, billing and discharge',
      icon: 'fa-receipt',
      buttonId: 'btn-cat-pharmacy-billing',
      badgeId: 'cat-badge-pharmacy-billing'
    }
  };

  const BANK_CATEGORY_METADATA = {
    'bank-basic-comm': {
      titleSi: '1. මූලික සන්නිවේදනය',
      titleEn: 'Basic communication',
      label: '1. මූලික සන්නිවේදනය / Basic communication',
      icon: 'fa-comments',
      buttonId: 'btn-cat-bank-basic-comm',
      badgeId: 'cat-badge-bank-basic-comm'
    },
    'bank-reception-queue': {
      titleSi: '2. පිළිගැනීමේ අංශය සහ පෝලිම',
      titleEn: 'Reception and queue',
      label: '2. පිළිගැනීමේ අංශය සහ පෝලිම / Reception and queue',
      icon: 'fa-users-line',
      buttonId: 'btn-cat-bank-reception-queue',
      badgeId: 'cat-badge-bank-reception-queue'
    },
    'bank-open-account': {
      titleSi: '3. ගිණුමක් විවෘත කිරීම',
      titleEn: 'Opening an account',
      label: '3. ගිණුමක් විවෘත කිරීම / Opening an account',
      icon: 'fa-user-plus',
      buttonId: 'btn-cat-bank-open-account',
      badgeId: 'cat-badge-bank-open-account'
    },
    'bank-deposits-withdrawals': {
      titleSi: '4. තැන්පත් කිරීම් සහ මුදල් ආපසු ගැනීම්',
      titleEn: 'Deposits and withdrawals',
      label: '4. තැන්පත් කිරීම් සහ මුදල් ආපසු ගැනීම් / Deposits and withdrawals',
      icon: 'fa-money-bill-wave',
      buttonId: 'btn-cat-bank-deposits-withdrawals',
      badgeId: 'cat-badge-bank-deposits-withdrawals'
    },
    'bank-cards-atm': {
      titleSi: '5. කාඩ්පත් සහ ATM',
      titleEn: 'Cards and ATM',
      label: '5. කාඩ්පත් සහ ATM / Cards and ATM',
      icon: 'fa-credit-card',
      buttonId: 'btn-cat-bank-cards-atm',
      badgeId: 'cat-badge-bank-cards-atm'
    },
    'bank-loans': {
      titleSi: '6. ණය',
      titleEn: 'Loans',
      label: '6. ණය / Loans',
      icon: 'fa-hand-holding-dollar',
      buttonId: 'btn-cat-bank-loans',
      badgeId: 'cat-badge-bank-loans'
    },
    'bank-transfers-payments': {
      titleSi: '7. මාරු කිරීම් සහ ගෙවීම්',
      titleEn: 'Transfers and payments',
      label: '7. මාරු කිරීම් සහ ගෙවීම් / Transfers and payments',
      icon: 'fa-arrow-right-arrow-left',
      buttonId: 'btn-cat-bank-transfers-payments',
      badgeId: 'cat-badge-bank-transfers-payments'
    },
    'bank-account-services': {
      titleSi: '8. ගිණුම් සේවා සහ ගැටළු',
      titleEn: 'Account services and problems',
      label: '8. ගිණුම් සේවා සහ ගැටළු / Account services and problems',
      icon: 'fa-file-lines',
      buttonId: 'btn-cat-bank-account-services',
      badgeId: 'cat-badge-bank-account-services'
    },
    'bank-security-fraud': {
      titleSi: '9. ආරක්ෂාව සහ වංචා',
      titleEn: 'Security and fraud',
      label: '9. ආරක්ෂාව සහ වංචා / Security and fraud',
      icon: 'fa-shield-halved',
      buttonId: 'btn-cat-bank-security-fraud',
      badgeId: 'cat-badge-bank-security-fraud'
    },
    'bank-closing-courtesy': {
      titleSi: '10. ආචාරශීලී වදන් සහ සමුගැනීම',
      titleEn: 'Closing and courtesy',
      label: '10. ආචාරශීලී වදන් සහ සමුගැනීම / Closing and courtesy',
      icon: 'fa-handshake',
      buttonId: 'btn-cat-bank-closing-courtesy',
      badgeId: 'cat-badge-bank-closing-courtesy'
    }
  };

  const ALL_HOSPITAL_CAT_KEYS = [
    'basic-comm',
    'reception',
    'directions',
    'symptoms',
    'emergency',
    'medical-history',
    'doctor-consultation',
    'procedures-comfort',
    'pharmacy-billing'
  ];

  const ALL_BANK_CAT_KEYS = [
    'bank-basic-comm',
    'bank-reception-queue',
    'bank-open-account',
    'bank-deposits-withdrawals',
    'bank-cards-atm',
    'bank-loans',
    'bank-transfers-payments',
    'bank-account-services',
    'bank-security-fraud',
    'bank-closing-courtesy'
  ];

  let cachedRestaurantCategories = {
    'rest-basic-comm': [
      { id: 1, template: "I am deaf.", template_en: "I am deaf.", template_si: "මම බිහිරි කෙනෙක්.", icon: "fa-ear-deaf", category: "Basic communication" },
      { id: 2, template: "I cannot speak.", template_en: "I cannot speak.", template_si: "මට කතා කරන්න බැහැ.", icon: "fa-comment-slash", category: "Basic communication" },
      { id: 3, template: "Please write down your message.", template_en: "Please write down your message.", template_si: "කරුණාකර ඔබේ පණිවිඩය ලියන්න.", icon: "fa-pen", category: "Basic communication" },
      { id: 4, template: "Please speak slowly and face me.", template_en: "Please speak slowly and face me.", template_si: "කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.", icon: "fa-eye", category: "Basic communication" },
      { id: 5, template: "Please wait a moment.", template_en: "Please wait a moment.", template_si: "කරුණාකර මොහොතක් රැඳී සිටින්න.", icon: "fa-hourglass-half", category: "Basic communication" },
      { id: 6, template: "Please repeat that.", template_en: "Please repeat that.", template_si: "කරුණාකර නැවත කියන්න.", icon: "fa-rotate-left", category: "Basic communication" },
      { id: 7, template: "I do not understand.", template_en: "I do not understand.", template_si: "මට තේරෙන්නේ නැහැ.", icon: "fa-circle-question", category: "Basic communication" },
      { id: 8, template: "Yes.", template_en: "Yes.", template_si: "ඔව්.", icon: "fa-circle-check", category: "Basic communication" },
      { id: 9, template: "No.", template_en: "No.", template_si: "නැහැ.", icon: "fa-circle-xmark", category: "Basic communication" },
      { id: 10, template: "Thank you.", template_en: "Thank you.", template_si: "ස්තූතියි.", icon: "fa-heart", category: "Basic communication" }
    ],
    'rest-seating': [
      { id: 1, template: "A table for one, please.", template_en: "A table for one, please.", template_si: "කරුණාකර එක් අයෙකුට මේසයක් දෙන්න.", icon: "fa-user", category: "Arrival and seating" },
      { id: 2, template: "A table for two, please.", template_en: "A table for two, please.", template_si: "කරුණාකර දෙදෙනෙකුට මේසයක් දෙන්න.", icon: "fa-user-group", category: "Arrival and seating" },
      { id: 3, template: "A table for three, please.", template_en: "A table for three, please.", template_si: "කරුණාකර තුන් දෙනෙකුට මේසයක් දෙන්න.", icon: "fa-users", category: "Arrival and seating" },
      { id: 4, template: "A table for four, please.", template_en: "A table for four, please.", template_si: "කරුණාකර හතර දෙනෙකුට මේසයක් දෙන්න.", icon: "fa-users-rectangle", category: "Arrival and seating" },
      { id: 5, template: "A table for a larger group, please.", template_en: "A table for a larger group, please.", template_si: "කරුණාකර විශාල කණ්ඩායමකට මේසයක් දෙන්න.", icon: "fa-people-group", category: "Arrival and seating" },
      { id: 6, template: "I have a reservation.", template_en: "I have a reservation.", template_si: "මම මේසයක් වෙන්කරගෙන තියෙනවා.", icon: "fa-calendar-check", category: "Arrival and seating" },
      { id: 7, template: "The reservation is under my name.", template_en: "The reservation is under my name.", template_si: "වෙන්කිරීම මගේ නමින්.", icon: "fa-id-card", category: "Arrival and seating" },
      { id: 8, template: "How long is the waiting time?", template_en: "How long is the waiting time?", template_si: "බලා සිටිය යුතු කාලය කොපමණ ද?", icon: "fa-clock", category: "Arrival and seating" },
      { id: 9, template: "May we sit near the window?", template_en: "May we sit near the window?", template_si: "අපිට ජනේලය ළඟ ඉන්න පුළුවන් ද?", icon: "fa-table", category: "Arrival and seating" },
      { id: 10, template: "May we sit in a quiet area?", template_en: "May we sit in a quiet area?", template_si: "අපිට නිශ්ශබ්ද ස්ථානයක ඉන්න පුළුවන් ද?", icon: "fa-volume-xmark", category: "Arrival and seating" },
      { id: 11, template: "May we sit in a well-lit area?", template_en: "May we sit in a well-lit area?", template_si: "අපිට හොඳ ආලෝකයක් ඇති ස්ථානයක ඉන්න පුළුවන් ද?", icon: "fa-lightbulb", category: "Arrival and seating" },
      { id: 12, template: "Where is the toilet?", template_en: "Where is the toilet?", template_si: "වැසිකිළිය කොහෙද?", icon: "fa-restroom", category: "Arrival and seating" }
    ],
    'rest-menu-ordering': [
      { id: 1, template: "May I see the menu, please?", template_en: "May I see the menu, please?", template_si: "කරුණාකර මට මෙනුව බලන්න පුළුවන් ද?", icon: "fa-book-open", category: "Menu and ordering" },
      { id: 2, template: "Is there a menu with pictures?", template_en: "Is there a menu with pictures?", template_si: "පින්තූර සහිත මෙනුවක් තියෙනවා ද?", icon: "fa-image", category: "Menu and ordering" },
      { id: 3, template: "I am ready to order.", template_en: "I am ready to order.", template_si: "මම ඇණවුම් කිරීමට සූදානම්.", icon: "fa-bell-concierge", category: "Menu and ordering" },
      { id: 4, template: "I need a little more time.", template_en: "I need a little more time.", template_si: "මට තව ටිකක් කාලය අවශ්යයි.", icon: "fa-hourglass-start", category: "Menu and ordering" },
      { id: 5, template: "What do you recommend?", template_en: "What do you recommend?", template_si: "ඔබ නිර්දේශ කරන්නේ කුමක්ද?", icon: "fa-star", category: "Menu and ordering" },
      { id: 6, template: "What is the most popular dish?", template_en: "What is the most popular dish?", template_si: "වැඩිපුරම ජනප්රිය කෑම වර්ගය කුමක්ද?", icon: "fa-fire", category: "Menu and ordering" },
      { id: 7, template: "I would like this one. (pointing at the menu)", template_en: "I would like this one. (pointing at the menu)", template_si: "මට මෙය අවශ්යයි.", icon: "fa-hand-pointer", category: "Menu and ordering" },
      { id: 8, template: "I would like rice and curry.", template_en: "I would like rice and curry.", template_si: "මට බත් සහ ව්යංජන අවශ්යයි.", icon: "fa-bowl-rice", category: "Menu and ordering" },
      { id: 9, template: "I would like fried rice.", template_en: "I would like fried rice.", template_si: "මට ෆ්රයිඩ් රයිස් අවශ්යයි.", icon: "fa-bowl-rice", category: "Menu and ordering" },
      { id: 10, template: "I would like kottu.", template_en: "I would like kottu.", template_si: "මට කොත්තු අවශ්යයි.", icon: "fa-utensils", category: "Menu and ordering" },
      { id: 11, template: "I would like noodles.", template_en: "I would like noodles.", template_si: "මට නූඩ්ල්ස් අවශ්යයි.", icon: "fa-plate-wheat", category: "Menu and ordering" },
      { id: 12, template: "I would like string hoppers.", template_en: "I would like string hoppers.", template_si: "මට ඉඳිආප්ප අවශ්යයි.", icon: "fa-circle-notch", category: "Menu and ordering" },
      { id: 13, template: "I would like hoppers.", template_en: "I would like hoppers.", template_si: "මට ආප්ප අවශ්යයි.", icon: "fa-circle", category: "Menu and ordering" },
      { id: 14, template: "I would like a sandwich or a burger.", template_en: "I would like a sandwich or a burger.", template_si: "මට සැන්ඩ්විච් එකක් හෝ බර්ගර් එකක් අවශ්යයි.", icon: "fa-burger", category: "Menu and ordering" },
      { id: 15, template: "I would like the same as that table.", template_en: "I would like the same as that table.", template_si: "මට අර මේසයේ තියෙන දේම අවශ්යයි.", icon: "fa-clone", category: "Menu and ordering" },
      { id: 16, template: "Is this dish available today?", template_en: "Is this dish available today?", template_si: "මෙම කෑම අද තියෙනවා ද?", icon: "fa-calendar-day", category: "Menu and ordering" },
      { id: 17, template: "Please repeat my order.", template_en: "Please repeat my order.", template_si: "කරුණාකර මගේ ඇණවුම නැවත කියන්න.", icon: "fa-list-check", category: "Menu and ordering" },
      { id: 18, template: "That is all for now.", template_en: "That is all for now.", template_si: "දැනට ඒ ඇති.", icon: "fa-check", category: "Menu and ordering" }
    ],
    'rest-drinks': [
      { id: 1, template: "May I have some water, please?", template_en: "May I have some water, please?", template_si: "කරුණාකර මට වතුර ටිකක් දෙන්න.", icon: "fa-glass-water", category: "Drinks" },
      { id: 2, template: "I would like hot water.", template_en: "I would like hot water.", template_si: "මට උණු වතුර අවශ්යයි.", icon: "fa-mug-hot", category: "Drinks" },
      { id: 3, template: "I would like a cup of tea.", template_en: "I would like a cup of tea.", template_si: "මට තේ කෝප්පයක් අවශ්යයි.", icon: "fa-mug-saucer", category: "Drinks" },
      { id: 4, template: "I would like a cup of coffee.", template_en: "I would like a cup of coffee.", template_si: "මට කෝපි කෝප්පයක් අවශ්යයි.", icon: "fa-coffee", category: "Drinks" },
      { id: 5, template: "I would like a fresh juice.", template_en: "I would like a fresh juice.", template_si: "මට පළතුරු යුෂ වීදුරුවක් අවශ්යයි.", icon: "fa-wine-glass", category: "Drinks" },
      { id: 6, template: "I would like a soft drink.", template_en: "I would like a soft drink.", template_si: "මට සීතල බීමක් අවශ්යයි.", icon: "fa-bottle-water", category: "Drinks" },
      { id: 7, template: "I would like a king coconut.", template_en: "I would like a king coconut.", template_si: "මට තැඹිලි පොල් එකක් අවශ්යයි.", icon: "fa-circle-dot", category: "Drinks" },
      { id: 8, template: "I would like a drink without ice.", template_en: "I would like a drink without ice.", template_si: "මට අයිස් නැති බීමක් අවශ්යයි.", icon: "fa-temperature-arrow-up", category: "Drinks" },
      { id: 9, template: "Without sugar, please.", template_en: "Without sugar, please.", template_si: "කරුණාකර සීනි නැතිව.", icon: "fa-cubes-stacked", category: "Drinks" },
      { id: 10, template: "May I have a refill, please?", template_en: "May I have a refill, please?", template_si: "කරුණාකර මට නැවත පුරවා දෙන්න පුළුවන් ද?", icon: "fa-arrows-rotate", category: "Drinks" }
    ],
    'rest-dietary-allergies': [
      { id: 1, template: "I am vegetarian.", template_en: "I am vegetarian.", template_si: "මම නිර්මාංශිකයි.", icon: "fa-seedling", category: "Dietary needs and allergies" },
      { id: 2, template: "I do not eat meat.", template_en: "I do not eat meat.", template_si: "මම මස් කන්නේ නැහැ.", icon: "fa-drumstick-bite", category: "Dietary needs and allergies" },
      { id: 3, template: "I do not eat pork.", template_en: "I do not eat pork.", template_si: "මම ඌරු මස් කන්නේ නැහැ.", icon: "fa-ban", category: "Dietary needs and allergies" },
      { id: 4, template: "I do not eat beef.", template_en: "I do not eat beef.", template_si: "මම හරක් මස් කන්නේ නැහැ.", icon: "fa-ban", category: "Dietary needs and allergies" },
      { id: 5, template: "I do not eat fish.", template_en: "I do not eat fish.", template_si: "මම මාළු කන්නේ නැහැ.", icon: "fa-fish", category: "Dietary needs and allergies" },
      { id: 6, template: "Is this halal?", template_en: "Is this halal?", template_si: "මෙය හලාල් ද?", icon: "fa-certificate", category: "Dietary needs and allergies" },
      { id: 7, template: "I am allergic to nuts.", template_en: "I am allergic to nuts.", template_si: "මට පරිප්පු වර්ග වලට අසාත්මිකතාවක් තියෙනවා.", icon: "fa-shield-halved", category: "Dietary needs and allergies" },
      { id: 8, template: "I am allergic to seafood.", template_en: "I am allergic to seafood.", template_si: "මට මුහුදු ආහාර වලට අසාත්මිකතාවක් තියෙනවා.", icon: "fa-shrimp", category: "Dietary needs and allergies" },
      { id: 9, template: "I am allergic to eggs.", template_en: "I am allergic to eggs.", template_si: "මට බිත්තර වලට අසාත්මිකතාවක් තියෙනවා.", icon: "fa-egg", category: "Dietary needs and allergies" },
      { id: 10, template: "I am allergic to milk and dairy.", template_en: "I am allergic to milk and dairy.", template_si: "මට කිරි සහ කිරි නිෂ්පාදන වලට අසාත්මිකතාවක් තියෙනවා.", icon: "fa-cow", category: "Dietary needs and allergies" },
      { id: 11, template: "Does this dish contain nuts?", template_en: "Does this dish contain nuts?", template_si: "මෙම කෑමේ පරිප්පු අඩංගු ද?", icon: "fa-triangle-exclamation", category: "Dietary needs and allergies" },
      { id: 12, template: "I am diabetic. Please give me no sugar.", template_en: "I am diabetic. Please give me no sugar.", template_si: "මම දියවැඩියා රෝගියෙක්. කරුණාකර සීනි නැතිව දෙන්න.", icon: "fa-square-plus", category: "Dietary needs and allergies" },
      { id: 13, template: "Please check with the kitchen about allergies.", template_en: "Please check with the kitchen about allergies.", template_si: "කරුණාකර අසාත්මිකතා ගැන කුස්සියෙන් විමසන්න.", icon: "fa-kitchen-set", category: "Dietary needs and allergies" },
      { id: 14, template: "Please write down the ingredients.", template_en: "Please write down the ingredients.", template_si: "කරුණාකර අමුද්රව්ය ලියන්න.", icon: "fa-clipboard-list", category: "Dietary needs and allergies" }
    ],
    'rest-customizing': [
      { id: 1, template: "Not too spicy, please.", template_en: "Not too spicy, please.", template_si: "කරුණාකර වැඩි ඇඹුල් හෝ සැර නැතිව.", icon: "fa-pepper-hot", category: "Customizing the food" },
      { id: 2, template: "Please make it mild.", template_en: "Please make it mild.", template_si: "කරුණාකර සැර අඩුවෙන් දෙන්න.", icon: "fa-temperature-low", category: "Customizing the food" },
      { id: 3, template: "I like it spicy.", template_en: "I like it spicy.", template_si: "මම සැර කෑම කැමතියි.", icon: "fa-fire-flame-curved", category: "Customizing the food" },
      { id: 4, template: "Less salt, please.", template_en: "Less salt, please.", template_si: "කරුණාකර ලුණු අඩුවෙන් දාන්න.", icon: "fa-mortar-pestle", category: "Customizing the food" },
      { id: 5, template: "Without onions, please.", template_en: "Without onions, please.", template_si: "කරුණාකර ලූණු නැතිව.", icon: "fa-circle-minus", category: "Customizing the food" },
      { id: 6, template: "Without chili, please.", template_en: "Without chili, please.", template_si: "කරුණාකර මිරිස් නැතිව.", icon: "fa-circle-minus", category: "Customizing the food" },
      { id: 7, template: "A small portion, please.", template_en: "A small portion, please.", template_si: "කරුණාකර කුඩා කොටසක් දෙන්න.", icon: "fa-compress", category: "Customizing the food" },
      { id: 8, template: "A large portion, please.", template_en: "A large portion, please.", template_si: "කරුණාකර විශාල කොටසක් දෙන්න.", icon: "fa-expand", category: "Customizing the food" },
      { id: 9, template: "May I have extra rice?", template_en: "May I have extra rice?", template_si: "මට අමතර බත් ටිකක් දෙන්න පුළුවන් ද?", icon: "fa-plus", category: "Customizing the food" },
      { id: 10, template: "May I have extra gravy?", template_en: "May I have extra gravy?", template_si: "මට අමතර ග්රේවි ටිකක් දෙන්න පුළුවන් ද?", icon: "fa-plus", category: "Customizing the food" },
      { id: 11, template: "May I have a spoon and fork?", template_en: "May I have a spoon and fork?", template_si: "මට හැන්දක් සහ ගෑරුප්පුවක් දෙන්න පුළුවන් ද?", icon: "fa-utensils", category: "Customizing the food" },
      { id: 12, template: "May I have a napkin or tissue?", template_en: "May I have a napkin or tissue?", template_si: "මට නැප්කින් එකක් හෝ ටිෂූ එකක් දෙන්න පුළුවන් ද?", icon: "fa-box-tissue", category: "Customizing the food" }
    ],
    'rest-during-meal': [
      { id: 1, template: "How long will my food take?", template_en: "How long will my food take?", template_si: "මගේ කෑම ලැබෙන්න කොපමණ කාලයක් යයිද?", icon: "fa-stopwatch", category: "During the meal" },
      { id: 2, template: "This is not what I ordered.", template_en: "This is not what I ordered.", template_si: "මෙය මා ඇණවුම් කළ දේ නොවේ.", icon: "fa-circle-exclamation", category: "During the meal" },
      { id: 3, template: "My food is cold. Please heat it.", template_en: "My food is cold. Please heat it.", template_si: "මගේ කෑම සීතලයි. කරුණාකර රත් කරන්න.", icon: "fa-snowflake", category: "During the meal" },
      { id: 4, template: "This is too spicy.", template_en: "This is too spicy.", template_si: "මෙය ඉතා සැරයි.", icon: "fa-pepper-hot", category: "During the meal" },
      { id: 5, template: "This is too salty.", template_en: "This is too salty.", template_si: "මෙය ඉතා ලුණුයි.", icon: "fa-triangle-exclamation", category: "During the meal" },
      { id: 6, template: "There is something wrong with this food.", template_en: "There is something wrong with this food.", template_si: "මෙම කෑමේ යම් වැරැද්දක් තියෙනවා.", icon: "fa-bug", category: "During the meal" },
      { id: 7, template: "Please change this dish.", template_en: "Please change this dish.", template_si: "කරුණාකර මෙම කෑම මාරු කරන්න.", icon: "fa-rotate", category: "During the meal" },
      { id: 8, template: "The food is delicious.", template_en: "The food is delicious.", template_si: "කෑම ඉතා රසයි.", icon: "fa-face-smile", category: "During the meal" },
      { id: 9, template: "Please clear the table.", template_en: "Please clear the table.", template_si: "කරුණාකර මේසය පිරිසිදු කරන්න.", icon: "fa-broom", category: "During the meal" },
      { id: 10, template: "May I have another menu for dessert?", template_en: "May I have another menu for dessert?", template_si: "අතුරුපස සඳහා තවත් මෙනුවක් දෙන්න පුළුවන් ද?", icon: "fa-ice-cream", category: "During the meal" }
    ],
    'rest-takeaway-requests': [
      { id: 1, template: "May I have this packed to take away?", template_en: "May I have this packed to take away?", template_si: "මට මෙය රැගෙන යාමට ඇසුරුම් කරන්න පුළුවන් ද?", icon: "fa-box", category: "Takeaway and special requests" },
      { id: 2, template: "I would like a takeaway order.", template_en: "I would like a takeaway order.", template_si: "මට රැගෙන යන ඇණවුමක් අවශ්යයි.", icon: "fa-bag-shopping", category: "Takeaway and special requests" },
      { id: 3, template: "Do you deliver?", template_en: "Do you deliver?", template_si: "ඔබ බෙදාහරින්නේ ද?", icon: "fa-truck", category: "Takeaway and special requests" },
      { id: 4, template: "Is there Wi-Fi?", template_en: "Is there Wi-Fi?", template_si: "Wi-Fi තියෙනවා ද?", icon: "fa-wifi", category: "Takeaway and special requests" },
      { id: 5, template: "Please bring a pen and paper.", template_en: "Please bring a pen and paper.", template_si: "කරුණාකර පෑනක් සහ කඩදාසියක් ගෙන එන්න.", icon: "fa-pen-to-square", category: "Takeaway and special requests" },
      { id: 6, template: "Please tap my shoulder or wave to get my attention.", template_en: "Please tap my shoulder or wave to get my attention.", template_si: "කරුණාකර මගේ අවධානය ලබාගැනීමට උරහිසට තට්ටු කරන්න හෝ අත වනන්න.", icon: "fa-hand", category: "Takeaway and special requests" }
    ],
    'rest-bill-payment': [
      { id: 1, template: "May I have the bill, please?", template_en: "May I have the bill, please?", template_si: "කරුණාකර මට බිල දෙන්න.", icon: "fa-receipt", category: "Bill and payment" },
      { id: 2, template: "Please write down the total amount.", template_en: "Please write down the total amount.", template_si: "කරුණාකර මුළු මුදල ලියන්න.", icon: "fa-pen-clip", category: "Bill and payment" },
      { id: 3, template: "Can I pay by card?", template_en: "Can I pay by card?", template_si: "කාඩ්පතෙන් ගෙවන්න පුළුවන් ද?", icon: "fa-credit-card", category: "Bill and payment" },
      { id: 4, template: "I will pay in cash.", template_en: "I will pay in cash.", template_si: "මම මුදලින් ගෙවන්නම්.", icon: "fa-money-bill-wave", category: "Bill and payment" },
      { id: 5, template: "Is service charge included?", template_en: "Is service charge included?", template_si: "සේවා ගාස්තුව ඇතුළත් ද?", icon: "fa-percent", category: "Bill and payment" },
      { id: 6, template: "Can we split the bill?", template_en: "Can we split the bill?", template_si: "අපිට බිල බෙදාගන්න පුළුවන් ද?", icon: "fa-divide", category: "Bill and payment" },
      { id: 7, template: "Please keep the change.", template_en: "Please keep the change.", template_si: "කරුණාකර ඉතිරි මුදල තියාගන්න.", icon: "fa-coins", category: "Bill and payment" },
      { id: 8, template: "Thank you, we enjoyed the meal.", template_en: "Thank you, we enjoyed the meal.", template_si: "ස්තූතියි, අපි කෑම රස විඳිමු.", icon: "fa-face-laugh-beam", category: "Bill and payment" }
    ]
  };

  const RESTAURANT_CATEGORY_METADATA = {
    'rest-basic-comm': {
      titleSi: '1. මූලික සන්නිවේදනය',
      titleEn: 'Basic communication',
      label: '1. මූලික සන්නිවේදනය / Basic communication',
      icon: 'fa-comments',
      buttonId: 'btn-cat-rest-basic-comm',
      badgeId: 'cat-badge-rest-basic-comm'
    },
    'rest-seating': {
      titleSi: '2. පැමිණීම සහ අසුන් ගැනීම',
      titleEn: 'Arrival and seating',
      label: '2. පැමිණීම සහ අසුන් ගැනීම / Arrival and seating',
      icon: 'fa-chair',
      buttonId: 'btn-cat-rest-seating',
      badgeId: 'cat-badge-rest-seating'
    },
    'rest-menu-ordering': {
      titleSi: '3. මෙනුව සහ ඇණවුම් කිරීම',
      titleEn: 'Menu and ordering',
      label: '3. මෙනුව සහ ඇණවුම් කිරීම / Menu and ordering',
      icon: 'fa-bowl-food',
      buttonId: 'btn-cat-rest-menu-ordering',
      badgeId: 'cat-badge-rest-menu-ordering'
    },
    'rest-drinks': {
      titleSi: '4. බීම වර්ග',
      titleEn: 'Drinks',
      label: '4. බීම වර්ග / Drinks',
      icon: 'fa-mug-hot',
      buttonId: 'btn-cat-rest-drinks',
      badgeId: 'cat-badge-rest-drinks'
    },
    'rest-dietary-allergies': {
      titleSi: '5. ආහාර අවශ්‍යතා සහ අසාත්මිකතා',
      titleEn: 'Dietary needs and allergies',
      label: '5. ආහාර අවශ්‍යතා සහ අසාත්මිකතා / Dietary needs and allergies',
      icon: 'fa-wheat-awn-circle-exclamation',
      buttonId: 'btn-cat-rest-dietary-allergies',
      badgeId: 'cat-badge-rest-dietary-allergies'
    },
    'rest-customizing': {
      titleSi: '6. කෑම රිසිකරණය',
      titleEn: 'Customizing the food',
      label: '6. කෑම රිසිකරණය / Customizing the food',
      icon: 'fa-pepper-hot',
      buttonId: 'btn-cat-rest-customizing',
      badgeId: 'cat-badge-rest-customizing'
    },
    'rest-during-meal': {
      titleSi: '7. කෑම ගන්නා අතරතුර',
      titleEn: 'During the meal',
      label: '7. කෑම ගන්නා අතරතුර / During the meal',
      icon: 'fa-bell-concierge',
      buttonId: 'btn-cat-rest-during-meal',
      badgeId: 'cat-badge-rest-during-meal'
    },
    'rest-takeaway-requests': {
      titleSi: '8. රැගෙන යාම සහ විශේෂ ඉල්ලීම්',
      titleEn: 'Takeaway and special requests',
      label: '8. රැගෙන යාම සහ විශේෂ ඉල්ලීම් / Takeaway and special requests',
      icon: 'fa-box',
      buttonId: 'btn-cat-rest-takeaway-requests',
      badgeId: 'cat-badge-rest-takeaway-requests'
    },
    'rest-bill-payment': {
      titleSi: '9. බිල සහ ගෙවීම්',
      titleEn: 'Bill and payment',
      label: '9. බිල සහ ගෙවීම් / Bill and payment',
      icon: 'fa-receipt',
      buttonId: 'btn-cat-rest-bill-payment',
      badgeId: 'cat-badge-rest-bill-payment'
    }
  };

  const ALL_RESTAURANT_CAT_KEYS = [
    'rest-basic-comm',
    'rest-seating',
    'rest-menu-ordering',
    'rest-drinks',
    'rest-dietary-allergies',
    'rest-customizing',
    'rest-during-meal',
    'rest-takeaway-requests',
    'rest-bill-payment'
  ];

  const SUPERMARKET_DEFAULT_CATEGORIES = {
    'sm-basic-comm': [
      { id: 1, template: "I am deaf.", template_en: "I am deaf.", template_si: "මම බිහිරි කෙනෙක්.", icon: "fa-ear-deaf", category: "Basic communication" },
      { id: 2, template: "I cannot speak.", template_en: "I cannot speak.", template_si: "මට කතා කරන්න බැහැ.", icon: "fa-volume-xmark", category: "Basic communication" },
      { id: 3, template: "Please write down your message.", template_en: "Please write down your message.", template_si: "කරුණාකර ඔබේ පණිවිඩය ලියන්න.", icon: "fa-pen-to-square", category: "Basic communication" },
      { id: 4, template: "Please speak slowly and face me.", template_en: "Please speak slowly and face me.", template_si: "කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.", icon: "fa-face-smile", category: "Basic communication" },
      { id: 5, template: "Please wait a moment.", template_en: "Please wait a moment.", template_si: "කරුණාකර මොහොතක් රැඳී සිටින්න.", icon: "fa-clock", category: "Basic communication" },
      { id: 6, template: "Please repeat that.", template_en: "Please repeat that.", template_si: "කරුණාකර නැවත කියන්න.", icon: "fa-rotate-right", category: "Basic communication" },
      { id: 7, template: "I do not understand.", template_en: "I do not understand.", template_si: "මට තේරෙන්නේ නැහැ.", icon: "fa-circle-question", category: "Basic communication" },
      { id: 8, template: "Yes.", template_en: "Yes.", template_si: "ඔව්.", icon: "fa-circle-check", category: "Basic communication" },
      { id: 9, template: "No.", template_en: "No.", template_si: "නැහැ.", icon: "fa-circle-xmark", category: "Basic communication" },
      { id: 10, template: "Thank you.", template_en: "Thank you.", template_si: "ස්තූතියි.", icon: "fa-hands-clapping", category: "Basic communication" }
    ],
    'sm-help-facilities': [
      { id: 11, template: "I need help.", template_en: "I need help.", template_si: "මට උදව්වක් අවශ්යයි.", icon: "fa-hand-holding-hand", category: "Getting help and facilities" },
      { id: 12, template: "Can you help me find something?", template_en: "Can you help me find something?", template_si: "මට යමක් සොයාගැනීමට උදව් කරන්න පුළුවන් ද?", icon: "fa-magnifying-glass", category: "Getting help and facilities" },
      { id: 13, template: "Where is the customer service desk?", template_en: "Where is the customer service desk?", template_si: "ගනුදෙනුකරු සේවා මේසය කොහෙද?", icon: "fa-circle-info", category: "Getting help and facilities" },
      { id: 14, template: "May I speak to the manager?", template_en: "May I speak to the manager?", template_si: "මට කළමනාකරු හමුවීමට පුළුවන් ද?", icon: "fa-user-tie", category: "Getting help and facilities" },
      { id: 15, template: "Where is the toilet?", template_en: "Where is the toilet?", template_si: "වැසිකිළිය කොහෙද?", icon: "fa-restroom", category: "Getting help and facilities" },
      { id: 16, template: "Where is the entrance?", template_en: "Where is the entrance?", template_si: "ඇතුල්වීමේ දොර කොහෙද?", icon: "fa-door-open", category: "Getting help and facilities" },
      { id: 17, template: "Where is the exit?", template_en: "Where is the exit?", template_si: "පිටවීමේ දොර කොහෙද?", icon: "fa-door-closed", category: "Getting help and facilities" },
      { id: 18, template: "Where can I get a trolley?", template_en: "Where can I get a trolley?", template_si: "ට්රොලිය ලබාගන්නේ කොහෙන්ද?", icon: "fa-cart-shopping", category: "Getting help and facilities" },
      { id: 19, template: "Where can I get a shopping basket?", template_en: "Where can I get a shopping basket?", template_si: "සාප්පු කූඩයක් ලබාගන්නේ කොහෙන්ද?", icon: "fa-basket-shopping", category: "Getting help and facilities" },
      { id: 20, template: "Can you show me the way?", template_en: "Can you show me the way?", template_si: "මට පාර පෙන්වන්න පුළුවන් ද?", icon: "fa-map-location-dot", category: "Getting help and facilities" }
    ],
    'sm-finding-products': [
      { id: 21, template: "Where is the rice?", template_en: "Where is the rice?", template_si: "සහල් කොහෙද?", icon: "fa-bowl-rice", category: "Finding products" },
      { id: 22, template: "Where is the milk?", template_en: "Where is the milk?", template_si: "කිරි කොහෙද?", icon: "fa-bottle-water", category: "Finding products" },
      { id: 23, template: "Where is the bread?", template_en: "Where is the bread?", template_si: "පාන් කොහෙද?", icon: "fa-bread-slice", category: "Finding products" },
      { id: 24, template: "Where is the vegetable section?", template_en: "Where is the vegetable section?", template_si: "එළවළු අංශය කොහෙද?", icon: "fa-carrot", category: "Finding products" },
      { id: 25, template: "Where is the fruit section?", template_en: "Where is the fruit section?", template_si: "පළතුරු අංශය කොහෙද?", icon: "fa-apple-whole", category: "Finding products" },
      { id: 26, template: "Where is the meat section?", template_en: "Where is the meat section?", template_si: "මස් අංශය කොහෙද?", icon: "fa-drumstick-bite", category: "Finding products" },
      { id: 27, template: "Where is the fish section?", template_en: "Where is the fish section?", template_si: "මාළු අංශය කොහෙද?", icon: "fa-fish", category: "Finding products" },
      { id: 28, template: "Where is the dairy section?", template_en: "Where is the dairy section?", template_si: "කිරි නිෂ්පාදන අංශය කොහෙද?", icon: "fa-cheese", category: "Finding products" },
      { id: 29, template: "Where is the bakery section?", template_en: "Where is the bakery section?", template_si: "බේකරි අංශය කොහෙද?", icon: "fa-cake-candles", category: "Finding products" },
      { id: 30, template: "Where are the spices?", template_en: "Where are the spices?", template_si: "කුළුබඩු කොහෙද?", icon: "fa-pepper-hot", category: "Finding products" },
      { id: 31, template: "Where is the cooking oil?", template_en: "Where is the cooking oil?", template_si: "පිසින තෙල් කොහෙද?", icon: "fa-oil-can", category: "Finding products" },
      { id: 32, template: "Where are the eggs?", template_en: "Where are the eggs?", template_si: "බිත්තර කොහෙද?", icon: "fa-egg", category: "Finding products" },
      { id: 33, template: "Where is the sugar?", template_en: "Where is the sugar?", template_si: "සීනි කොහෙද?", icon: "fa-cubes-stacked", category: "Finding products" },
      { id: 34, template: "Where is the salt?", template_en: "Where is the salt?", template_si: "ලුණු කොහෙද?", icon: "fa-mortar-pestle", category: "Finding products" },
      { id: 35, template: "Where is the tea?", template_en: "Where is the tea?", template_si: "තේ කොළ කොහෙද?", icon: "fa-mug-hot", category: "Finding products" },
      { id: 36, template: "Where is the flour?", template_en: "Where is the flour?", template_si: "පිටි කොහෙද?", icon: "fa-wheat-awn", category: "Finding products" },
      { id: 37, template: "Where are the lentils?", template_en: "Where are the lentils?", template_si: "පරිප්පු කොහෙද?", icon: "fa-seedling", category: "Finding products" },
      { id: 38, template: "Where are the snacks?", template_en: "Where are the snacks?", template_si: "කෙටි ආහාර (ස්නැක්ස්) කොහෙද?", icon: "fa-cookie-bite", category: "Finding products" },
      { id: 39, template: "Where are the beverages?", template_en: "Where are the beverages?", template_si: "බීම වර්ග කොහෙද?", icon: "fa-wine-glass", category: "Finding products" },
      { id: 40, template: "Where are the frozen foods?", template_en: "Where are the frozen foods?", template_si: "ශීත කළ ආහාර කොහෙද?", icon: "fa-snowflake", category: "Finding products" },
      { id: 41, template: "Where are the cleaning products?", template_en: "Where are the cleaning products?", template_si: "පිරිසිදු කිරීමේ නිෂ්පාදන කොහෙද?", icon: "fa-pump-soap", category: "Finding products" },
      { id: 42, template: "Where are the personal care items?", template_en: "Where are the personal care items?", template_si: "පුද්ගලික සුව පහසු භාණ්ඩ කොහෙද?", icon: "fa-spa", category: "Finding products" },
      { id: 43, template: "Where are the baby products?", template_en: "Where are the baby products?", template_si: "ළදරු භාණ්ඩ කොහෙද?", icon: "fa-baby", category: "Finding products" },
      { id: 44, template: "Where are the household items?", template_en: "Where are the household items?", template_si: "ගෘහ භාණ්ඩ කොහෙද?", icon: "fa-couch", category: "Finding products" },
      { id: 45, template: "Where are the batteries?", template_en: "Where are the batteries?", template_si: "බැටරි කොහෙද?", icon: "fa-battery-full", category: "Finding products" },
      { id: 46, template: "Do you have this item? (showing a picture)", template_en: "Do you have this item? (showing a picture)", template_si: "ඔබ ළඟ මෙම භාණ්ඩය තියෙනවා ද?", icon: "fa-image", category: "Finding products" }
    ],
    'sm-prices-offers': [
      { id: 47, template: "How much is this?", template_en: "How much is this?", template_si: "මෙය කීයද?", icon: "fa-tag", category: "Prices and offers" },
      { id: 48, template: "There is no price tag on this.", template_en: "There is no price tag on this.", template_si: "මෙයට මිල ලේබලයක් නැහැ.", icon: "fa-tags", category: "Prices and offers" },
      { id: 49, template: "Can you check the price for me?", template_en: "Can you check the price for me?", template_si: "මට මිල පරීක්ෂා කර දෙන්න පුළුවන් ද?", icon: "fa-barcode", category: "Prices and offers" },
      { id: 50, template: "Please write down the price.", template_en: "Please write down the price.", template_si: "කරුණාකර මිල ලියන්න.", icon: "fa-pen", category: "Prices and offers" },
      { id: 51, template: "Is this on sale?", template_en: "Is this on sale?", template_si: "මෙය අඩු මිලට තියෙනවා ද?", icon: "fa-percent", category: "Prices and offers" },
      { id: 52, template: "Are there any discounts today?", template_en: "Are there any discounts today?", template_si: "අද වට්ටම් තියෙනවා ද?", icon: "fa-badge-percent", category: "Prices and offers" },
      { id: 53, template: "I have a membership card.", template_en: "I have a membership card.", template_si: "මා ළඟ සාමාජික කාඩ්පතක් තියෙනවා.", icon: "fa-id-card", category: "Prices and offers" },
      { id: 54, template: "I have a discount coupon.", template_en: "I have a discount coupon.", template_si: "මා ළඟ වට්ටම් කූපනයක් තියෙනවා.", icon: "fa-ticket", category: "Prices and offers" },
      { id: 55, template: "Do you have a cheaper option?", template_en: "Do you have a cheaper option?", template_si: "මීට වඩා ලාභ විකල්පයක් තියෙනවා ද?", icon: "fa-coins", category: "Prices and offers" },
      { id: 56, template: "The price on the shelf is different.", template_en: "The price on the shelf is different.", template_si: "රාක්කයේ මිල වෙනස්.", icon: "fa-arrows-split-up-and-left", category: "Prices and offers" }
    ],
    'sm-product-info-dietary': [
      { id: 57, template: "What is the expiry date?", template_en: "What is the expiry date?", template_si: "කල් ඉකුත් වන දිනය කුමක්ද?", icon: "fa-calendar-xmark", category: "Product information and dietary needs" },
      { id: 58, template: "Please check the expiry date for me.", template_en: "Please check the expiry date for me.", template_si: "කරුණාකර කල් ඉකුත් වන දිනය බලා දෙන්න.", icon: "fa-calendar-check", category: "Product information and dietary needs" },
      { id: 59, template: "Is there a fresher one?", template_en: "Is there a fresher one?", template_si: "මීට වඩා නැවුම් එකක් තියෙනවා ද?", icon: "fa-leaf", category: "Product information and dietary needs" },
      { id: 60, template: "Does this contain nuts? I am allergic.", template_en: "Does this contain nuts? I am allergic.", template_si: "මෙහි පරිප්පු අඩංගු ද? මට අසාත්මිකතාවක් තියෙනවා.", icon: "fa-shield-virus", category: "Product information and dietary needs" },
      { id: 61, template: "Please check the ingredients for me.", template_en: "Please check the ingredients for me.", template_si: "කරුණාකර අමුද්රව්ය බලා දෙන්න.", icon: "fa-list-check", category: "Product information and dietary needs" },
      { id: 62, template: "I am diabetic. Do you have sugar-free products?", template_en: "I am diabetic. Do you have sugar-free products?", template_si: "මම දියවැඩියා රෝගියෙක්. සීනි රහිත නිෂ්පාදන තියෙනවා ද?", icon: "fa-heart-pulse", category: "Product information and dietary needs" },
      { id: 63, template: "Do you have low-salt products?", template_en: "Do you have low-salt products?", template_si: "ලුණු අඩු නිෂ්පාදන තියෙනවා ද?", icon: "fa-bottle-droplet", category: "Product information and dietary needs" },
      { id: 64, template: "Is this suitable for vegetarians?", template_en: "Is this suitable for vegetarians?", template_si: "මෙය නිර්මාංශිකයන්ට සුදුසු ද?", icon: "fa-seedling", category: "Product information and dietary needs" },
      { id: 65, template: "Is this halal?", template_en: "Is this halal?", template_si: "මෙය හලාල් ද?", icon: "fa-circle-check", category: "Product information and dietary needs" },
      { id: 66, template: "Do you have gluten-free products?", template_en: "Do you have gluten-free products?", template_si: "ග්ලූටන් රහිත නිෂ්පාදන තියෙනවා ද?", icon: "fa-wheat-awn-circle-exclamation", category: "Product information and dietary needs" },
      { id: 67, template: "Do you have a larger size?", template_en: "Do you have a larger size?", template_si: "විශාල ප්රමාණයක් තියෙනවා ද?", icon: "fa-up-right-and-down-left-from-center", category: "Product information and dietary needs" },
      { id: 68, template: "Do you have a smaller size?", template_en: "Do you have a smaller size?", template_si: "කුඩා ප්රමාණයක් තියෙනවා ද?", icon: "fa-down-left-and-up-right-to-center", category: "Product information and dietary needs" }
    ],
    'sm-weighing-packing': [
      { id: 69, template: "Please weigh this for me.", template_en: "Please weigh this for me.", template_si: "කරුණාකර මෙය කිරලා දෙන්න.", icon: "fa-scale-balanced", category: "Weighing, cutting and packing" },
      { id: 70, template: "I would like 250 grams.", template_en: "I would like 250 grams.", template_si: "මට ග්රෑම් 250ක් අවශ්යයි.", icon: "fa-weight-scale", category: "Weighing, cutting and packing" },
      { id: 71, template: "I would like half a kilogram.", template_en: "I would like half a kilogram.", template_si: "මට කිලෝ භාගයක් අවශ්යයි.", icon: "fa-weight-hanging", category: "Weighing, cutting and packing" },
      { id: 72, template: "I would like one kilogram.", template_en: "I would like one kilogram.", template_si: "මට කිලෝවක් අවශ්යයි.", icon: "fa-weight-scale", category: "Weighing, cutting and packing" },
      { id: 73, template: "Please cut it into small pieces.", template_en: "Please cut it into small pieces.", template_si: "කරුණාකර කුඩා කෑලි වලට කපන්න.", icon: "fa-scissors", category: "Weighing, cutting and packing" },
      { id: 74, template: "Please clean the fish.", template_en: "Please clean the fish.", template_si: "කරුණාකර මාළු පිරිසිදු කරන්න.", icon: "fa-fish", category: "Weighing, cutting and packing" },
      { id: 75, template: "Please give me fresh ones.", template_en: "Please give me fresh ones.", template_si: "කරුණාකර නැවුම් ඒවා දෙන්න.", icon: "fa-apple-whole", category: "Weighing, cutting and packing" },
      { id: 76, template: "Please pack it separately.", template_en: "Please pack it separately.", template_si: "කරුණාකර වෙන වෙනම ඇසුරුම් කරන්න.", icon: "fa-box-archive", category: "Weighing, cutting and packing" }
    ],
    'sm-checkout-payment': [
      { id: 77, template: "Which counter is open?", template_en: "Which counter is open?", template_si: "කුමන කවුන්ටරය විවෘතද?", icon: "fa-door-open", category: "Checkout and payment" },
      { id: 78, template: "Is this the queue for payment?", template_en: "Is this the queue for payment?", template_si: "ගෙවීම සඳහා පෝලිම මෙයද?", icon: "fa-users-line", category: "Checkout and payment" },
      { id: 79, template: "I have only a few items. May I go first?", template_en: "I have only a few items. May I go first?", template_si: "මා ළඟ ඇත්තේ භාණ්ඩ කිහිපයයි. මට කලින් යන්න පුළුවන් ද?", icon: "fa-hand", category: "Checkout and payment" },
      { id: 80, template: "Please show me the total amount.", template_en: "Please show me the total amount.", template_si: "කරුණාකර මුළු මුදල මට පෙන්වන්න.", icon: "fa-calculator", category: "Checkout and payment" },
      { id: 81, template: "Please write down the total amount.", template_en: "Please write down the total amount.", template_si: "කරුණාකර මුළු මුදල ලියන්න.", icon: "fa-pen-to-square", category: "Checkout and payment" },
      { id: 82, template: "Can I pay by card?", template_en: "Can I pay by card?", template_si: "කාඩ්පතෙන් ගෙවන්න පුළුවන් ද?", icon: "fa-credit-card", category: "Checkout and payment" },
      { id: 83, template: "I will pay in cash.", template_en: "I will pay in cash.", template_si: "මම මුදලින් ගෙවන්නම්.", icon: "fa-money-bill-wave", category: "Checkout and payment" },
      { id: 84, template: "Can I pay using a QR code?", template_en: "Can I pay using a QR code?", template_si: "QR කේතයෙන් ගෙවන්න පුළුවන් ද?", icon: "fa-qrcode", category: "Checkout and payment" },
      { id: 85, template: "Please give me a receipt.", template_en: "Please give me a receipt.", template_si: "කරුණාකර රිසිට්පතක් දෙන්න.", icon: "fa-receipt", category: "Checkout and payment" },
      { id: 86, template: "May I have a bag, please?", template_en: "May I have a bag, please?", template_si: "කරුණාකර මට බෑගයක් දෙන්න.", icon: "fa-bag-shopping", category: "Checkout and payment" },
      { id: 87, template: "I have my own bag.", template_en: "I have my own bag.", template_si: "මා ළඟ මගේම බෑගයක් තියෙනවා.", icon: "fa-bag-shopping", category: "Checkout and payment" },
      { id: 88, template: "Please pack the items in separate bags.", template_en: "Please pack the items in separate bags.", template_si: "කරුණාකර භාණ්ඩ වෙනම බෑග් වල දාන්න.", icon: "fa-boxes-packing", category: "Checkout and payment" },
      { id: 89, template: "Can you help me carry my shopping?", template_en: "Can you help me carry my shopping?", template_si: "මගේ බඩු රැගෙන යාමට උදව් කරන්න පුළුවන් ද?", icon: "fa-person-walking-luggage", category: "Checkout and payment" },
      { id: 90, template: "I think the change is incorrect. Please check.", template_en: "I think the change is incorrect. Please check.", template_si: "ඉතිරි මුදල වැරදියි කියා මට හිතෙනවා. කරුණාකර පරීක්ෂා කරන්න.", icon: "fa-coins", category: "Checkout and payment" }
    ],
    'sm-problems-returns': [
      { id: 91, template: "I think I was charged twice.", template_en: "I think I was charged twice.", template_si: "මට දෙවරක් අය කළා කියා හිතෙනවා.", icon: "fa-triangle-exclamation", category: "Problems and returns" },
      { id: 92, template: "I want to return this item.", template_en: "I want to return this item.", template_si: "මට මෙම භාණ්ඩය ආපසු දීමට අවශ්යයි.", icon: "fa-arrow-rotate-left", category: "Problems and returns" },
      { id: 93, template: "I want to exchange this item.", template_en: "I want to exchange this item.", template_si: "මට මෙම භාණ්ඩය මාරු කරගැනීමට අවශ්යයි.", icon: "fa-right-left", category: "Problems and returns" },
      { id: 94, template: "This item is damaged.", template_en: "This item is damaged.", template_si: "මෙම භාණ්ඩය හානි වී තියෙනවා.", icon: "fa-box-open", category: "Problems and returns" },
      { id: 95, template: "This item is expired.", template_en: "This item is expired.", template_si: "මෙම භාණ්ඩය කල් ඉකුත් වී තියෙනවා.", icon: "fa-calendar-xmark", category: "Problems and returns" },
      { id: 96, template: "I want a refund.", template_en: "I want a refund.", template_si: "මට මුදල් ආපසු ලබාගැනීමට අවශ්යයි.", icon: "fa-hand-holding-dollar", category: "Problems and returns" }
    ],
    'sm-closing-courtesy': [
      { id: 97, template: "Please tap my shoulder or wave to get my attention.", template_en: "Please tap my shoulder or wave to get my attention.", template_si: "කරුණාකර මගේ අවධානය ලබාගැනීමට උරහිසට තට්ටු කරන්න හෝ අත වනන්න.", icon: "fa-hand", category: "Closing and courtesy" },
      { id: 98, template: "Do you offer home delivery?", template_en: "Do you offer home delivery?", template_si: "ඔබ ගෙදරටම බෙදාහරින්නේ ද?", icon: "fa-truck", category: "Closing and courtesy" },
      { id: 99, template: "What time do you close?", template_en: "What time do you close?", template_si: "ඔබ වසන්නේ කීයටද?", icon: "fa-clock", category: "Closing and courtesy" },
      { id: 100, template: "Thank you for your help.", template_en: "Thank you for your help.", template_si: "ඔබේ උදව්වට ස්තූතියි.", icon: "fa-hands-clapping", category: "Closing and courtesy" }
    ]
  };

  let cachedSupermarketCategories = JSON.parse(JSON.stringify(SUPERMARKET_DEFAULT_CATEGORIES));

  const SUPERMARKET_CATEGORY_METADATA = {
    'sm-basic-comm': {
      titleSi: '1. මූලික සන්නිවේදනය',
      titleEn: 'Basic communication',
      label: '1. මූලික සන්නිවේදනය / Basic communication',
      icon: 'fa-comments',
      buttonId: 'btn-cat-sm-basic-comm',
      badgeId: 'cat-badge-sm-basic-comm'
    },
    'sm-help-facilities': {
      titleSi: '2. ආධාර සහ පහසුකම් ලබා ගැනීම',
      titleEn: 'Getting help and facilities',
      label: '2. ආධාර සහ පහසුකම් ලබා ගැනීම / Getting help and facilities',
      icon: 'fa-hand-holding-hand',
      buttonId: 'btn-cat-sm-help-facilities',
      badgeId: 'cat-badge-sm-help-facilities'
    },
    'sm-finding-products': {
      titleSi: '3. නිෂ්පාදන සොයා ගැනීම',
      titleEn: 'Finding products',
      label: '3. නිෂ්පාදන සොයා ගැනීම / Finding products',
      icon: 'fa-boxes-stacked',
      buttonId: 'btn-cat-sm-finding-products',
      badgeId: 'cat-badge-sm-finding-products'
    },
    'sm-prices-offers': {
      titleSi: '4. මිල ගණන් සහ දීමනා',
      titleEn: 'Prices and offers',
      label: '4. මිල ගණන් සහ දීමනා / Prices and offers',
      icon: 'fa-tags',
      buttonId: 'btn-cat-sm-prices-offers',
      badgeId: 'cat-badge-sm-prices-offers'
    },
    'sm-product-info-dietary': {
      titleSi: '5. නිෂ්පාදන තොරතුරු සහ ආහාරමය අවශ්යතා',
      titleEn: 'Product information and dietary needs',
      label: '5. නිෂ්පාදන තොරතුරු සහ ආහාරමය අවශ්යතා / Product information and dietary needs',
      icon: 'fa-circle-info',
      buttonId: 'btn-cat-sm-product-info-dietary',
      badgeId: 'cat-badge-sm-product-info-dietary'
    },
    'sm-weighing-packing': {
      titleSi: '6. බර කිරා බැලීම, කැපීම සහ ඇසුරුම් කිරීම',
      titleEn: 'Weighing, cutting and packing',
      label: '6. බර කිරා බැලීම, කැපීම සහ ඇසුරුම් කිරීම / Weighing, cutting and packing',
      icon: 'fa-scale-balanced',
      buttonId: 'btn-cat-sm-weighing-packing',
      badgeId: 'cat-badge-sm-weighing-packing'
    },
    'sm-checkout-payment': {
      titleSi: '7. පිරික්සුම සහ ගෙවීම',
      titleEn: 'Checkout and payment',
      label: '7. පිරික්සුම සහ ගෙවීම / Checkout and payment',
      icon: 'fa-cash-register',
      buttonId: 'btn-cat-sm-checkout-payment',
      badgeId: 'cat-badge-sm-checkout-payment'
    },
    'sm-problems-returns': {
      titleSi: '8. නිෂ්පාදන ආපසු යැවීම',
      titleEn: 'Problems and returns',
      label: '8. නිෂ්පාදන ආපසු යැවීම / Problems and returns',
      icon: 'fa-arrow-rotate-left',
      buttonId: 'btn-cat-sm-problems-returns',
      badgeId: 'cat-badge-sm-problems-returns'
    },
    'sm-closing-courtesy': {
      titleSi: '9. සමාප්තිය සහ ආචාරශීලීත්වය',
      titleEn: 'Closing and courtesy',
      label: '9. සමාප්තිය සහ ආචාරශීලීත්වය / Closing and courtesy',
      icon: 'fa-handshake',
      buttonId: 'btn-cat-sm-closing-courtesy',
      badgeId: 'cat-badge-sm-closing-courtesy'
    }
  };

  const ALL_SUPERMARKET_CAT_KEYS = [
    'sm-basic-comm',
    'sm-help-facilities',
    'sm-finding-products',
    'sm-prices-offers',
    'sm-product-info-dietary',
    'sm-weighing-packing',
    'sm-checkout-payment',
    'sm-problems-returns',
    'sm-closing-courtesy'
  ];

  // Screen 1 & Screen 2 Navigation:
  // First screen displays only the Map and the Message Criteria for the detected/selected venue.
  // Tapping any criteria navigates to Screen 2 displaying the suggested messages for that criterion.
  function openCategoryMessagesScreen(catKey) {
    const screenMainHome = document.getElementById('screen-main-home');
    const screenCategoryMessages = document.getElementById('screen-category-messages');
    const messagesGrid = document.getElementById('messages-grid');
    const meta = HOSPITAL_CATEGORY_METADATA[catKey] || BANK_CATEGORY_METADATA[catKey] || RESTAURANT_CATEGORY_METADATA[catKey] || SUPERMARKET_CATEGORY_METADATA[catKey] || {
      titleSi: catKey,
      titleEn: catKey,
      label: catKey,
      icon: 'fa-comments'
    };

    let msgs = [];
    if (cachedHospitalCategories && cachedHospitalCategories[catKey]) {
      msgs = cachedHospitalCategories[catKey];
    } else if (cachedBankCategories && cachedBankCategories[catKey]) {
      msgs = cachedBankCategories[catKey];
    } else if (cachedRestaurantCategories && cachedRestaurantCategories[catKey]) {
      msgs = cachedRestaurantCategories[catKey];
    } else if (cachedSupermarketCategories && cachedSupermarketCategories[catKey]) {
      msgs = cachedSupermarketCategories[catKey];
    }

    // Populate Screen 2 Subscreen Header
    const subTitle = document.getElementById('subscreen-category-title');
    const subEn = document.getElementById('subscreen-category-en');
    const subCount = document.getElementById('subscreen-count-pill');
    const bannerTitle = document.getElementById('subscreen-banner-title');
    const bannerIcon = document.getElementById('subscreen-banner-icon');

    if (subTitle) subTitle.textContent = meta.titleSi || meta.label;
    if (subEn) subEn.textContent = meta.titleEn || '';
    if (subCount) subCount.textContent = msgs.length;
    if (bannerTitle) bannerTitle.textContent = `${meta.titleSi} / ${meta.titleEn}`;
    if (bannerIcon) bannerIcon.className = `fa-solid ${meta.icon || 'fa-comments'}`;

    // Render suggested messages
    renderHospitalMessages(msgs);
    if (messagesGrid) {
      messagesGrid.style.display = 'flex';
      messagesGrid.style.flexDirection = 'column';
      messagesGrid.scrollTop = 0;
    }

    currentActiveHospitalCategory = catKey;

    // Transition Screens: Hide Screen 1 (Map & Categories), Show Screen 2 (Suggested Messages)
    if (screenMainHome) {
      screenMainHome.style.display = 'none';
      screenMainHome.classList.remove('active');
    }
    if (screenCategoryMessages) {
      screenCategoryMessages.style.display = 'block';
      screenCategoryMessages.classList.add('active');
    }

    // Scroll container to top
    const mainContainer = document.getElementById('main-mobile-content');
    if (mainContainer) {
      mainContainer.scrollTo({ top: 0, behavior: 'smooth' });
    } else {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    showGpsToast(`💬 ${msgs.length} Suggested Messages: ${meta.titleEn}`, 2200);
  }

  // Return from Screen 2 back to Screen 1 (Map and Criteria)
  function backToFirstScreen() {
    const screenMainHome = document.getElementById('screen-main-home');
    const screenCategoryMessages = document.getElementById('screen-category-messages');

    if (screenCategoryMessages) {
      screenCategoryMessages.style.display = 'none';
      screenCategoryMessages.classList.remove('active');
    }
    if (screenMainHome) {
      screenMainHome.style.display = 'block';
      screenMainHome.classList.add('active');
    }

    // Invalidate map size so Leaflet map renders correctly after returning
    if (areaMap) {
      setTimeout(() => {
        areaMap.invalidateSize();
      }, 100);
    }
  }

  // Expose backToFirstScreen globally if needed
  window.backToFirstScreen = backToFirstScreen;
  window.openCategoryMessagesScreen = openCategoryMessagesScreen;

  // Bind Back Button on Screen 2
  const btnBackToHome = document.getElementById('btn-back-to-home');
  if (btnBackToHome) {
    btnBackToHome.addEventListener('click', backToFirstScreen);
  }

  // Bind all 9 Hospital Criteria Buttons to navigate to Screen 2
  ALL_HOSPITAL_CAT_KEYS.forEach(catKey => {
    const meta = HOSPITAL_CATEGORY_METADATA[catKey];
    if (meta) {
      const btn = document.getElementById(meta.buttonId);
      if (btn) {
        btn.addEventListener('click', () => openCategoryMessagesScreen(catKey));
      }
    }
  });

  // Bind all Bank Criteria Buttons to navigate to Screen 2
  ALL_BANK_CAT_KEYS.forEach(catKey => {
    const meta = BANK_CATEGORY_METADATA[catKey];
    if (meta) {
      const btn = document.getElementById(meta.buttonId);
      if (btn) {
        btn.addEventListener('click', () => openCategoryMessagesScreen(catKey));
      }
    }
  });

  // Bind all Restaurant Criteria Buttons to navigate to Screen 2
  ALL_RESTAURANT_CAT_KEYS.forEach(catKey => {
    const meta = RESTAURANT_CATEGORY_METADATA[catKey];
    if (meta) {
      const btn = document.getElementById(meta.buttonId);
      if (btn) {
        btn.addEventListener('click', () => openCategoryMessagesScreen(catKey));
      }
    }
  });

  // Bind all Supermarket Criteria Buttons to navigate to Screen 2
  ALL_SUPERMARKET_CAT_KEYS.forEach(catKey => {
    const meta = SUPERMARKET_CATEGORY_METADATA[catKey];
    if (meta) {
      const btn = document.getElementById(meta.buttonId);
      if (btn) {
        btn.addEventListener('click', () => openCategoryMessagesScreen(catKey));
      }
    }
  });

  // Backward compatibility alias
  function toggleHospitalCategory(catKey) {
    openCategoryMessagesScreen(catKey);
  }

  // 5. Custom Typing Sheet
  if (customTypingTrigger) {
    customTypingTrigger.addEventListener('click', () => {
      if (customSheetBackdrop) customSheetBackdrop.classList.add('open');
      if (customInputText) setTimeout(() => customInputText.focus(), 250);
    });
  }

  if (closeSheetBtn) {
    closeSheetBtn.addEventListener('click', () => {
      if (customSheetBackdrop) customSheetBackdrop.classList.remove('open');
    });
  }

  if (customSheetBackdrop) {
    customSheetBackdrop.addEventListener('click', (e) => {
      if (e.target === customSheetBackdrop) {
        customSheetBackdrop.classList.remove('open');
      }
    });
  }

  // Quick Suggestion Chips
  chipBtns.forEach(chip => {
    chip.addEventListener('click', () => {
      const phrase = chip.getAttribute('data-text');
      if (customInputText) {
        if (customInputText.value.trim()) {
          customInputText.value += ' ' + phrase;
        } else {
          customInputText.value = phrase;
        }
        customInputText.focus();
      }
    });
  });

  if (showCustomFullscreenBtn) {
    showCustomFullscreenBtn.addEventListener('click', () => {
      const text = customInputText ? customInputText.value.trim() : '';
      if (!text) {
        if (customInputText) customInputText.focus();
        return;
      }
      if (customSheetBackdrop) customSheetBackdrop.classList.remove('open');
      displayMessageBillboard(text, 'fa-pen');
    });
  }

  if (speakCustomBtn) {
    speakCustomBtn.addEventListener('click', () => {
      const text = customInputText ? customInputText.value.trim() : '';
      if (text) {
        speakMessage(text);
      }
    });
  }

  // 6. History Management
  function addToHistory(text, icon = 'fa-comment') {
    const item = {
      text: text,
      icon: icon,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };
    historyData = historyData.filter(h => h.text !== text);
    historyData.unshift(item);
    if (historyData.length > 20) historyData.pop();
    localStorage.setItem('assistcomm_history', JSON.stringify(historyData));
  }

  function renderHistory() {
    if (!historyList) return;
    historyList.innerHTML = '';
    if (historyData.length === 0) {
      if (historyEmpty) historyEmpty.style.display = 'block';
      if (clearHistoryBtn) clearHistoryBtn.style.display = 'none';
      return;
    }
    if (historyEmpty) historyEmpty.style.display = 'none';
    if (clearHistoryBtn) clearHistoryBtn.style.display = 'inline-block';

    historyData.forEach(item => {
      const row = document.createElement('div');
      row.className = 'history-item-row';
      row.innerHTML = `
        <div style="display:flex; align-items:center; gap:10px;">
          <i class="fa-solid ${item.icon}" style="color:#2563eb;"></i>
          <span class="history-item-content">${item.text}</span>
        </div>
        <span class="history-item-time">${item.time}</span>
      `;
      row.addEventListener('click', () => {
        displayMessageBillboard(item.text, item.icon);
      });
      historyList.appendChild(row);
    });
  }

  if (clearHistoryBtn) {
    clearHistoryBtn.addEventListener('click', () => {
      historyData = [];
      localStorage.removeItem('assistcomm_history');
      renderHistory();
    });
  }

  // 7. Favorites Management
  function toggleFavorite(text, icon = 'fa-comment') {
    const index = favoritesData.findIndex(f => f.text === text);
    if (index >= 0) {
      favoritesData.splice(index, 1);
      updateFavButtonUI(false);
      showGpsToast('Removed from Favorites', 1500);
    } else {
      favoritesData.push({ text, icon });
      updateFavButtonUI(true);
      showGpsToast('Saved to Favorites', 1500);
    }
    localStorage.setItem('assistcomm_favorites', JSON.stringify(favoritesData));
    syncCardFavIcons();
  }

  function syncCardFavIcons() {
    const cards = document.querySelectorAll('.msg-action-card');
    cards.forEach(card => {
      const msg = card.getAttribute('data-msg');
      const isFav = favoritesData.some(f => f.text === msg);
      const star = card.querySelector('.card-fav-star i');
      if (isFav) {
        card.classList.add('favorited');
        if (star) star.className = 'fa-solid fa-star';
      } else {
        card.classList.remove('favorited');
        if (star) star.className = 'fa-regular fa-star';
      }
    });
  }
  syncCardFavIcons();

  function renderFavorites() {
    if (!favoritesList) return;
    favoritesList.innerHTML = '';
    if (favoritesData.length === 0) {
      if (favoritesEmpty) favoritesEmpty.style.display = 'block';
      if (clearFavsBtn) clearFavsBtn.style.display = 'none';
      return;
    }
    if (favoritesEmpty) favoritesEmpty.style.display = 'none';
    if (clearFavsBtn) clearFavsBtn.style.display = 'inline-block';

    favoritesData.forEach(item => {
      const row = document.createElement('div');
      row.className = 'history-item-row';
      row.innerHTML = `
        <div style="display:flex; align-items:center; gap:10px;">
          <i class="fa-solid fa-star" style="color:#f59e0b;"></i>
          <span class="history-item-content">${item.text}</span>
        </div>
        <button class="btn-header-icon" title="Remove" style="font-size:12px; color:#ef4444;"><i class="fa-solid fa-trash"></i></button>
      `;
      row.querySelector('.history-item-content').addEventListener('click', () => {
        displayMessageBillboard(item.text, item.icon);
      });
      row.querySelector('button').addEventListener('click', (e) => {
        e.stopPropagation();
        toggleFavorite(item.text, item.icon);
        renderFavorites();
      });
      favoritesList.appendChild(row);
    });
  }

  if (clearFavsBtn) {
    clearFavsBtn.addEventListener('click', () => {
      favoritesData = [];
      localStorage.removeItem('assistcomm_favorites');
      renderFavorites();
      syncCardFavIcons();
    });
  }

  // 8. Drawer Navigation
  if (menuBtn && drawerBackdrop) {
    menuBtn.addEventListener('click', () => {
      drawerBackdrop.classList.add('open');
    });
  }

  if (closeDrawerBtn && drawerBackdrop) {
    closeDrawerBtn.addEventListener('click', () => {
      drawerBackdrop.classList.remove('open');
    });
  }

  if (drawerBackdrop) {
    drawerBackdrop.addEventListener('click', (e) => {
      if (e.target === drawerBackdrop) {
        drawerBackdrop.classList.remove('open');
      }
    });
  }

  // Accessibility Controls
  const contrastToggle = document.getElementById('contrast-toggle');
  if (contrastToggle) {
    contrastToggle.addEventListener('click', () => {
      document.body.classList.toggle('high-contrast');
    });
  }

  const darkToggle = document.getElementById('dark-toggle');
  if (darkToggle) {
    darkToggle.addEventListener('click', () => {
      document.body.classList.toggle('dark-mode');
    });
  }

  // 9. GPS Target & Live Button Detection Modal
  function openGpsDialog() {
    if (gpsDialogBackdrop) {
      gpsDialogBackdrop.classList.add('open');
    }
  }

  function closeGpsDialog() {
    if (gpsDialogBackdrop) {
      gpsDialogBackdrop.classList.remove('open');
    }
  }

  if (gpsTargetBtn) gpsTargetBtn.addEventListener('click', openGpsDialog);
  if (liveBadgeBtn) liveBadgeBtn.addEventListener('click', openGpsDialog);
  if (closeGpsDialogBtn) closeGpsDialogBtn.addEventListener('click', closeGpsDialog);
  if (previewOpenSimBtn) previewOpenSimBtn.addEventListener('click', openGpsDialog);
  if (gpsDialogBackdrop) {
    gpsDialogBackdrop.addEventListener('click', (e) => {
      if (e.target === gpsDialogBackdrop) closeGpsDialog();
    });
  }

  function showGpsToast(msg, duration = 3000) {
    if (!gpsToast) return;
    gpsToast.classList.add('show');
    if (gpsToastText) gpsToastText.textContent = msg;
    if (duration > 0) {
      setTimeout(() => {
        if (gpsToast) gpsToast.classList.remove('show');
      }, duration);
    }
  }

  // =========================================================================
  // 10. INTERACTIVE AREA MAP (Leaflet & OpenStreetMap)
  // Displays the user's area, real-time GPS pulse, accuracy radius,
  // and prominently highlights all major Sri Lanka Hospitals!
  // =========================================================================

  function initAreaMap() {
    const mapContainer = document.getElementById('leaflet-area-map');
    if (!mapContainer || typeof L === 'undefined') return;

    try {
      // Default Initial View: Centered in Colombo, Sri Lanka (lat: 6.9271, lon: 79.8612)
      // This immediately shows the surrounding hospitals in Sri Lanka!
      areaMap = L.map('leaflet-area-map', {
        zoomControl: false,
        attributionControl: false
      }).setView([6.9271, 79.8612], 13);

      // OpenStreetMap tiles
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 19,
        subdomains: ['a', 'b', 'c']
      }).addTo(areaMap);

      // Position Zoom Controls in top-left
      L.control.zoom({ position: 'topleft' }).addTo(areaMap);

      // Layer group for Sri Lanka Hospitals (Red Medical Pins)
      sriLankaHospitalsLayer = L.layerGroup().addTo(areaMap);

      // Layer group for Sri Lanka Banks (Blue Financial Pins)
      sriLankaBanksLayer = L.layerGroup().addTo(areaMap);

      // Layer group for Sri Lanka Restaurants (Amber Dining Pins)
      sriLankaRestaurantsLayer = L.layerGroup().addTo(areaMap);

      // Layer group for Sri Lanka Supermarkets (Green Grocery Pins)
      sriLankaSupermarketsLayer = L.layerGroup().addTo(areaMap);

      // Layer group for other facility pins
      venueMarkersGroup = L.layerGroup().addTo(areaMap);

      // Render all Sri Lanka hospitals, banks, restaurants, and supermarkets onto the map immediately
      renderSriLankaHospitals(allHospitalsData);
      renderSriLankaBanks(allBanksData);
      renderSriLankaRestaurants(allRestaurantsData);
      renderSriLankaSupermarkets(allSupermarketsData);

      // Recenter Button
      const recenterBtn = document.getElementById('map-recenter-btn');
      if (recenterBtn) {
        recenterBtn.addEventListener('click', () => {
          if (currentCoordinates && areaMap) {
            areaMap.flyTo([currentCoordinates.lat, currentCoordinates.lon], 16, { animate: true, duration: 1 });
            if (userGpsMarker) userGpsMarker.openPopup();
          } else {
            detectDeviceGps(false);
          }
        });
      }

      // Sri Lanka Hospitals Quick View Button (Shows all hospitals across Sri Lanka)
      const slHospitalsQuickBtn = document.getElementById('map-sl-hospitals-quick-btn');
      if (slHospitalsQuickBtn) {
        slHospitalsQuickBtn.addEventListener('click', () => {
          fitAllSriLankaHospitals();
        });
      }

      // Sri Lanka Banks Quick View Button (Shows all banks across Sri Lanka)
      const slBanksQuickBtn = document.getElementById('map-sl-banks-quick-btn');
      if (slBanksQuickBtn) {
        slBanksQuickBtn.addEventListener('click', () => {
          fitAllSriLankaBanks();
        });
      }

      // Sri Lanka Restaurants Quick View Button (Shows all restaurants across Sri Lanka)
      const slRestaurantsQuickBtn = document.getElementById('map-sl-restaurants-quick-btn');
      if (slRestaurantsQuickBtn) {
        slRestaurantsQuickBtn.addEventListener('click', () => {
          fitAllSriLankaRestaurants();
        });
      }

      // Sri Lanka Supermarkets Quick View Button (Shows all supermarkets across Sri Lanka)
      const slSupermarketsQuickBtn = document.getElementById('map-sl-supermarkets-quick-btn');
      if (slSupermarketsQuickBtn) {
        slSupermarketsQuickBtn.addEventListener('click', () => {
          fitAllSriLankaSupermarkets();
        });
      }

      const slHospitalsFocusBtn = document.getElementById('map-hospitals-focus-btn');
      if (slHospitalsFocusBtn) {
        slHospitalsFocusBtn.addEventListener('click', () => {
          areaMap.flyTo([6.9197, 79.8693], 14, { animate: true, duration: 1 });
          showGpsToast("🏙️ Focused on Central Colombo Venues (Hospitals, Banks, Dining & Groceries)", 2500);
        });
      }

      // Map Expand / Collapse Toggle Button
      const mapToggleBtn = document.getElementById('map-toggle-btn');
      const mapToggleIcon = document.getElementById('map-toggle-icon');
      if (mapToggleBtn) {
        mapToggleBtn.addEventListener('click', () => {
          if (!isMapExpanded) {
            mapContainer.classList.add('expanded');
            mapContainer.classList.remove('collapsed');
            if (mapToggleIcon) mapToggleIcon.className = 'fa-solid fa-chevron-down';
            isMapExpanded = true;
          } else {
            mapContainer.classList.remove('expanded');
            mapContainer.classList.remove('collapsed');
            if (mapToggleIcon) mapToggleIcon.className = 'fa-solid fa-chevron-up';
            isMapExpanded = false;
          }
          setTimeout(() => {
            if (areaMap) areaMap.invalidateSize();
          }, 320);
        });
      }

      // Map click handler: clicking near any hospital, bank, restaurant or supermarket on the map selects it directly
      areaMap.on('click', (e) => {
        let closestHosp = null;
        let minDHosp = Infinity;
        if (allHospitalsData && allHospitalsData.length > 0) {
          allHospitalsData.forEach(h => {
            const d = Math.hypot(e.latlng.lat - h.lat, e.latlng.lng - h.lon);
            if (d < minDHosp) {
              minDHosp = d;
              closestHosp = h;
            }
          });
        }

        let closestBank = null;
        let minDBank = Infinity;
        if (allBanksData && allBanksData.length > 0) {
          allBanksData.forEach(b => {
            const d = Math.hypot(e.latlng.lat - b.lat, e.latlng.lng - b.lon);
            if (d < minDBank) {
              minDBank = d;
              closestBank = b;
            }
          });
        }

        let closestRest = null;
        let minDRest = Infinity;
        if (allRestaurantsData && allRestaurantsData.length > 0) {
          allRestaurantsData.forEach(r => {
            const d = Math.hypot(e.latlng.lat - r.lat, e.latlng.lng - r.lon);
            if (d < minDRest) {
              minDRest = d;
              closestRest = r;
            }
          });
        }

        let closestSM = null;
        let minDSM = Infinity;
        if (allSupermarketsData && allSupermarketsData.length > 0) {
          allSupermarketsData.forEach(sm => {
            const d = Math.hypot(e.latlng.lat - sm.lat, e.latlng.lng - sm.lon);
            if (d < minDSM) {
              minDSM = d;
              closestSM = sm;
            }
          });
        }

        if (minDHosp <= minDBank && minDHosp <= minDRest && minDHosp <= minDSM && closestHosp && minDHosp < 0.04) {
          selectHospitalFromMap(closestHosp.id, closestHosp.lat, closestHosp.lon, closestHosp.name);
        } else if (minDBank <= minDRest && minDBank <= minDSM && closestBank && minDBank < 0.04) {
          selectBankFromMap(closestBank.id, closestBank.lat, closestBank.lon, closestBank.name);
        } else if (minDRest <= minDSM && closestRest && minDRest < 0.04) {
          selectRestaurantFromMap(closestRest.id, closestRest.lat, closestRest.lon, closestRest.name);
        } else if (closestSM && minDSM < 0.04) {
          selectSupermarketFromMap(closestSM.id, closestSM.lat, closestSM.lon, closestSM.name);
        }
      });
    } catch (err) {
      console.warn("Leaflet initialization error:", err);
    }
  }

  // Render Sri Lanka Hospital Markers with High-Visibility RED Pins & Direct 1-Tap Selection
  function renderSriLankaHospitals(hospitalsList) {
    if (!sriLankaHospitalsLayer || typeof L === 'undefined') return;
    sriLankaHospitalsLayer.clearLayers();
    hospitalMarkersMap = {};

    hospitalsList.forEach(hosp => {
      const distanceLabel = hosp.distance_km !== undefined 
        ? `<div style="font-size:11px; color:#ef4444; font-weight:700; margin-bottom:4px;"><i class="fa-solid fa-route"></i> ${hosp.distance_km} km away</div>` 
        : '';

      const hospIcon = L.divIcon({
        className: 'custom-hosp-pin-wrapper',
        html: `
          <div class="map-hospital-pin" id="map-pin-${hosp.id}" title="Tap on map to select Hospital: ${hosp.name}">
            <div class="hospital-pin-icon-wrap"><i class="fa-solid fa-square-h"></i></div>
            <span class="hospital-pin-title">${hosp.short_name || hosp.name}</span>
          </div>
        `,
        iconSize: [null, 28],
        iconAnchor: [15, 14],
        popupAnchor: [0, -14]
      });

      const marker = L.marker([hosp.lat, hosp.lon], { icon: hospIcon, zIndexOffset: 500 });
      marker.hospitalData = hosp;
      hospitalMarkersMap[hosp.id] = marker;

      marker.bindPopup(`
        <div class="hospital-leaflet-popup">
          <div class="hosp-popup-header" style="color:#ef4444;">
            <i class="fa-solid fa-square-h"></i> Hospital (Red Pin)
          </div>
          <h4 class="hosp-popup-name">${hosp.name}</h4>
          <p class="hosp-popup-meta"><strong>Location:</strong> ${hosp.city}, ${hosp.district} District</p>
          <p class="hosp-popup-meta"><strong>Type:</strong> ${hosp.type}</p>
          ${distanceLabel}
          <div style="font-size:11.5px; font-weight:700; color:#ef4444; margin:6px 0; background:#fee2e2; padding:5px 8px; border-radius:6px; text-align:center;">
            <i class="fa-solid fa-check"></i> Tap to select hospital
          </div>
        </div>
      `);

      // DIRECT 1-TAP SELECTION WHEN TAPPING PIN ON THE MAP
      marker.on('click', () => {
        selectHospitalFromMap(hosp.id, hosp.lat, hosp.lon, hosp.name);
      });

      sriLankaHospitalsLayer.addLayer(marker);
    });

    renderMapCombinedPills();
  }

  // Render Sri Lanka Bank Markers with High-Visibility BLUE Pins & Direct 1-Tap Selection
  function renderSriLankaBanks(banksList) {
    if (!sriLankaBanksLayer || typeof L === 'undefined') return;
    sriLankaBanksLayer.clearLayers();
    bankMarkersMap = {};

    banksList.forEach(bank => {
      const distanceLabel = bank.distance_km !== undefined 
        ? `<div style="font-size:11px; color:#2563eb; font-weight:700; margin-bottom:4px;"><i class="fa-solid fa-route"></i> ${bank.distance_km} km away</div>` 
        : '';

      const bankIcon = L.divIcon({
        className: 'custom-bank-pin-wrapper',
        html: `
          <div class="map-bank-pin" id="map-pin-${bank.id}" title="Tap on map to select Bank: ${bank.name}">
            <div class="bank-pin-icon-wrap"><i class="fa-solid fa-building-columns"></i></div>
            <span class="bank-pin-title">${bank.short_name || bank.name}</span>
          </div>
        `,
        iconSize: [null, 28],
        iconAnchor: [15, 14],
        popupAnchor: [0, -14]
      });

      const marker = L.marker([bank.lat, bank.lon], { icon: bankIcon, zIndexOffset: 480 });
      marker.bankData = bank;
      bankMarkersMap[bank.id] = marker;

      marker.bindPopup(`
        <div class="bank-leaflet-popup">
          <div class="bank-popup-header" style="color:#2563eb;">
            <i class="fa-solid fa-building-columns"></i> Bank & Finance (Blue Pin)
          </div>
          <h4 class="bank-popup-name">${bank.name}</h4>
          <p class="bank-popup-meta"><strong>Location:</strong> ${bank.city}, ${bank.district} District</p>
          <p class="bank-popup-meta"><strong>Type:</strong> ${bank.type}</p>
          ${bank.hotline ? `<p class="bank-popup-phone"><i class="fa-solid fa-phone"></i> Hotline: ${bank.hotline}</p>` : ''}
          ${distanceLabel}
          <div style="font-size:11.5px; font-weight:700; color:#2563eb; margin:6px 0; background:#dbeafe; padding:5px 8px; border-radius:6px; text-align:center;">
            <i class="fa-solid fa-check"></i> Tap to select bank
          </div>
        </div>
      `);

      // DIRECT 1-TAP SELECTION WHEN TAPPING PIN ON THE MAP
      marker.on('click', () => {
        selectBankFromMap(bank.id, bank.lat, bank.lon, bank.name);
      });

      sriLankaBanksLayer.addLayer(marker);
    });

    renderMapCombinedPills();
  }

  // Render Sri Lanka Restaurant Markers with High-Visibility AMBER Pins & Direct 1-Tap Selection
  function renderSriLankaRestaurants(restaurantsList) {
    if (!sriLankaRestaurantsLayer || typeof L === 'undefined') return;
    sriLankaRestaurantsLayer.clearLayers();
    restaurantMarkersMap = {};

    restaurantsList.forEach(rest => {
      const distanceLabel = rest.distance_km !== undefined 
        ? `<div style="font-size:11px; color:#d97706; font-weight:700; margin-bottom:4px;"><i class="fa-solid fa-route"></i> ${rest.distance_km} km away</div>` 
        : '';

      const restIcon = L.divIcon({
        className: 'custom-rest-pin-wrapper',
        html: `
          <div class="map-restaurant-pin" id="map-pin-${rest.id}" title="Tap on map to select Restaurant: ${rest.name}">
            <div class="restaurant-pin-icon-wrap"><i class="fa-solid fa-utensils"></i></div>
            <span class="restaurant-pin-title">${rest.short_name || rest.name}</span>
          </div>
        `,
        iconSize: [null, 28],
        iconAnchor: [15, 14],
        popupAnchor: [0, -14]
      });

      const marker = L.marker([rest.lat, rest.lon], { icon: restIcon, zIndexOffset: 460 });
      marker.restaurantData = rest;
      restaurantMarkersMap[rest.id] = marker;

      marker.bindPopup(`
        <div class="restaurant-leaflet-popup">
          <div class="restaurant-popup-header" style="color:#d97706;">
            <i class="fa-solid fa-utensils"></i> Restaurant (Amber Pin)
          </div>
          <h4 class="restaurant-popup-name">${rest.name}</h4>
          <p class="restaurant-popup-meta"><strong>Location:</strong> ${rest.city || (rest.district + ' District')}</p>
          <p class="restaurant-popup-meta"><strong>Cuisine:</strong> ${rest.cuisine || 'Dining & Cafe'}</p>
          ${rest.phone ? `<p class="restaurant-popup-phone"><i class="fa-solid fa-phone"></i> Tel: ${rest.phone}</p>` : ''}
          ${distanceLabel}
          <div style="font-size:11.5px; font-weight:700; color:#d97706; margin:6px 0; background:#fef3c7; padding:5px 8px; border-radius:6px; text-align:center;">
            <i class="fa-solid fa-check"></i> Tap to select restaurant
          </div>
        </div>
      `);

      // DIRECT 1-TAP SELECTION WHEN TAPPING PIN ON THE MAP
      marker.on('click', () => {
        selectRestaurantFromMap(rest.id, rest.lat, rest.lon, rest.name);
      });

      sriLankaRestaurantsLayer.addLayer(marker);
    });

    renderMapCombinedPills();
  }

  // Render Horizontal Pills Strip on Map (Hospitals in Red, Banks in Blue, Restaurants in Amber)
  function renderMapCombinedPills() {
    const pillsRow = document.getElementById('map-hospital-pills-row');
    if (!pillsRow) return;
    pillsRow.innerHTML = '';

    // 1. Render Hospital Pills (Red)
    (allHospitalsData || []).forEach(hosp => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'map-hospital-pill-btn';
      btn.setAttribute('data-id', hosp.id);
      btn.innerHTML = `<i class="fa-solid fa-square-h"></i> ${hosp.short_name || hosp.name}`;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        selectHospitalFromMap(hosp.id, hosp.lat, hosp.lon, hosp.name);
      });
      pillsRow.appendChild(btn);
    });

    // 2. Render Bank Pills (Blue)
    (allBanksData || []).forEach(bank => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'map-bank-pill-btn';
      btn.setAttribute('data-id', bank.id);
      btn.innerHTML = `<i class="fa-solid fa-building-columns"></i> ${bank.short_name || bank.name}`;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        selectBankFromMap(bank.id, bank.lat, bank.lon, bank.name);
      });
      pillsRow.appendChild(btn);
    });

    // 3. Render Restaurant Pills (Amber)
    (allRestaurantsData || []).forEach(rest => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'map-restaurant-pill-btn';
      btn.setAttribute('data-id', rest.id);
      btn.innerHTML = `<i class="fa-solid fa-utensils"></i> ${rest.short_name || rest.name}`;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        selectRestaurantFromMap(rest.id, rest.lat, rest.lon, rest.name);
      });
      pillsRow.appendChild(btn);
    });

    // 4. Render Supermarket Pills (Green)
    (allSupermarketsData || []).forEach(sm => {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'map-supermarket-pill-btn';
      btn.setAttribute('data-id', sm.id);
      btn.innerHTML = `<i class="fa-solid fa-cart-shopping"></i> ${sm.short_name || sm.name}`;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        selectSupermarketFromMap(sm.id, sm.lat, sm.lon, sm.name);
      });
      pillsRow.appendChild(btn);
    });
  }

  // Render Sri Lanka Supermarket Markers with High-Visibility GREEN Pins & Direct 1-Tap Selection
  function renderSriLankaSupermarkets(supermarketsList) {
    if (!sriLankaSupermarketsLayer || typeof L === 'undefined') return;
    sriLankaSupermarketsLayer.clearLayers();
    supermarketMarkersMap = {};

    supermarketsList.forEach(sm => {
      const distanceLabel = sm.distance_km !== undefined 
        ? `<div style="font-size:11px; color:#059669; font-weight:700; margin-bottom:4px;"><i class="fa-solid fa-route"></i> ${sm.distance_km} km away</div>` 
        : '';

      const smIcon = L.divIcon({
        className: 'custom-sm-pin-wrapper',
        html: `
          <div class="map-supermarket-pin" id="map-pin-${sm.id}" title="Tap on map to select Supermarket: ${sm.name}">
            <div class="supermarket-pin-icon-wrap"><i class="fa-solid fa-cart-shopping"></i></div>
            <span class="supermarket-pin-title">${sm.short_name || sm.name}</span>
          </div>
        `,
        iconSize: [null, 28],
        iconAnchor: [15, 14],
        popupAnchor: [0, -14]
      });

      const marker = L.marker([sm.lat, sm.lon], { icon: smIcon, zIndexOffset: 450 });
      marker.supermarketData = sm;
      supermarketMarkersMap[sm.id] = marker;

      marker.bindPopup(`
        <div class="supermarket-leaflet-popup">
          <div class="supermarket-popup-header" style="color:#059669;">
            <i class="fa-solid fa-cart-shopping"></i> Supermarket (Green Pin)
          </div>
          <h4 class="supermarket-popup-name">${sm.name}</h4>
          <p class="supermarket-popup-meta"><strong>Location:</strong> ${sm.city || (sm.district + ' District')}</p>
          <p class="supermarket-popup-meta"><strong>Chain:</strong> ${sm.chain || 'Supermarket & Groceries'}</p>
          ${sm.phone ? `<p class="supermarket-popup-phone"><i class="fa-solid fa-phone"></i> Tel: ${sm.phone}</p>` : ''}
          ${distanceLabel}
          <div style="font-size:11.5px; font-weight:700; color:#059669; margin:6px 0; background:#d1fae5; padding:5px 8px; border-radius:6px; text-align:center;">
            <i class="fa-solid fa-check"></i> Tap to select supermarket
          </div>
        </div>
      `);

      // DIRECT 1-TAP SELECTION WHEN TAPPING PIN ON THE MAP
      marker.on('click', () => {
        selectSupermarketFromMap(sm.id, sm.lat, sm.lon, sm.name);
      });

      sriLankaSupermarketsLayer.addLayer(marker);
    });

    renderMapCombinedPills();
  }

  function renderMapHospitalPills(hospitalsList) {
    if (hospitalsList) allHospitalsData = hospitalsList;
    renderMapCombinedPills();
  }

  // Core Function: Select Hospital Directly From Map
  function selectHospitalFromMap(id, lat, lon, name) {
    // 1. Highlight map pin
    document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
    const targetPin = document.getElementById(`map-pin-${id}`);
    if (targetPin) {
      targetPin.classList.add('selected-map-pin');
    }

    // 2. Highlight map pill button
    document.querySelectorAll('.map-hospital-pill-btn, .map-bank-pill-btn, .map-restaurant-pill-btn, .map-supermarket-pill-btn').forEach(btn => {
      if (btn.getAttribute('data-id') === id) {
        btn.classList.add('active-hospital-pill');
        btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      } else {
        btn.classList.remove('active-hospital-pill', 'active-bank-pill', 'active-restaurant-pill', 'active-supermarket-pill');
      }
    });

    // 3. Open marker popup
    if (hospitalMarkersMap[id]) {
      hospitalMarkersMap[id].openPopup();
    }

    // 4. Trigger selection & message suggestions
    manuallySelectHospital(id, lat, lon, name);
  }

  // Core Function: Select Bank Directly From Map
  function selectBankFromMap(id, lat, lon, name) {
    // 1. Highlight map pin
    document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
    const targetPin = document.getElementById(`map-pin-${id}`);
    if (targetPin) {
      targetPin.classList.add('selected-map-pin');
    }

    // 2. Highlight map pill button
    document.querySelectorAll('.map-hospital-pill-btn, .map-bank-pill-btn, .map-restaurant-pill-btn, .map-supermarket-pill-btn').forEach(btn => {
      if (btn.getAttribute('data-id') === id) {
        btn.classList.add('active-bank-pill');
        btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      } else {
        btn.classList.remove('active-hospital-pill', 'active-bank-pill', 'active-restaurant-pill', 'active-supermarket-pill');
      }
    });

    // 3. Open marker popup
    if (bankMarkersMap[id]) {
      bankMarkersMap[id].openPopup();
    }

    // 4. Trigger selection
    manuallySelectBank(id, lat, lon, name);
  }

  // Core Function: Select Restaurant Directly From Map
  function selectRestaurantFromMap(id, lat, lon, name) {
    // 1. Highlight map pin
    document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
    const targetPin = document.getElementById(`map-pin-${id}`);
    if (targetPin) {
      targetPin.classList.add('selected-map-pin');
    }

    // 2. Highlight map pill button
    document.querySelectorAll('.map-hospital-pill-btn, .map-bank-pill-btn, .map-restaurant-pill-btn, .map-supermarket-pill-btn').forEach(btn => {
      if (btn.getAttribute('data-id') === id) {
        btn.classList.add('active-restaurant-pill');
        btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      } else {
        btn.classList.remove('active-hospital-pill', 'active-bank-pill', 'active-restaurant-pill', 'active-supermarket-pill');
      }
    });

    // 3. Open marker popup
    if (restaurantMarkersMap[id]) {
      restaurantMarkersMap[id].openPopup();
    }

    // 4. Trigger selection
    manuallySelectRestaurant(id, lat, lon, name);
  }

  // Core Function: Select Supermarket Directly From Map
  function selectSupermarketFromMap(id, lat, lon, name) {
    // 1. Highlight map pin
    document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
    const targetPin = document.getElementById(`map-pin-${id}`);
    if (targetPin) {
      targetPin.classList.add('selected-map-pin');
    }

    // 2. Highlight map pill button
    document.querySelectorAll('.map-hospital-pill-btn, .map-bank-pill-btn, .map-restaurant-pill-btn, .map-supermarket-pill-btn').forEach(btn => {
      if (btn.getAttribute('data-id') === id) {
        btn.classList.add('active-supermarket-pill');
        btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      } else {
        btn.classList.remove('active-hospital-pill', 'active-bank-pill', 'active-restaurant-pill', 'active-supermarket-pill');
      }
    });

    // 3. Open marker popup
    if (supermarketMarkersMap[id]) {
      supermarketMarkersMap[id].openPopup();
    }

    // 4. Trigger selection
    manuallySelectSupermarket(id, lat, lon, name);
  }

  function fitAllSriLankaHospitals() {
    if (!areaMap || allHospitalsData.length === 0 || typeof L === 'undefined') return;
    const bounds = L.latLngBounds(allHospitalsData.map(h => [h.lat, h.lon]));
    areaMap.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });
    showGpsToast(`🗺️ Displaying all ${allHospitalsData.length} major hospitals (Red) across Sri Lanka`, 2500);
  }

  function fitAllSriLankaBanks() {
    if (!areaMap || allBanksData.length === 0 || typeof L === 'undefined') return;
    const bounds = L.latLngBounds(allBanksData.map(b => [b.lat, b.lon]));
    areaMap.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });
    showGpsToast(`🏦 Displaying all ${allBanksData.length} major banks (Blue) across Sri Lanka`, 2500);
  }

  function fitAllSriLankaRestaurants() {
    if (!areaMap || allRestaurantsData.length === 0 || typeof L === 'undefined') return;
    const bounds = L.latLngBounds(allRestaurantsData.map(r => [r.lat, r.lon]));
    areaMap.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });
    showGpsToast(`🍽️ Displaying all ${allRestaurantsData.length} popular restaurants (Amber) across Sri Lanka`, 2500);
  }

  function fitAllSriLankaSupermarkets() {
    if (!areaMap || allSupermarketsData.length === 0 || typeof L === 'undefined') return;
    const bounds = L.latLngBounds(allSupermarketsData.map(s => [s.lat, s.lon]));
    areaMap.fitBounds(bounds, { padding: [30, 30], maxZoom: 15 });
    showGpsToast(`🛒 Displaying all ${allSupermarketsData.length} supermarkets (Green) across Sri Lanka`, 2500);
  }

  function renderVenuePins(facilities) {
    if (!venueMarkersGroup || typeof L === 'undefined') return;
    venueMarkersGroup.clearLayers();
  }

  // Global helper for Leaflet popups and manual buttons to select a hospital, bank, restaurant, or supermarket
  window.selectHospitalFromMap = selectHospitalFromMap;
  window.selectHospitalManually = selectHospitalFromMap;
  window.triggerSimulateHospital = selectHospitalFromMap;
  window.selectBankFromMap = selectBankFromMap;
  window.selectBankManually = selectBankFromMap;
  window.selectRestaurantFromMap = selectRestaurantFromMap;
  window.selectRestaurantManually = selectRestaurantFromMap;
  window.selectSupermarketFromMap = selectSupermarketFromMap;
  window.selectSupermarketManually = selectSupermarketFromMap;

  window.triggerSimulateFromMap = function(slug) {
    simulateGpsLocation(slug);
  };

  // =========================================================================
  // 11. CORE ENGINE: GPS DETECTION & SITUATIONAL MESSAGE DELIVERY
  // The system detects the user's location via GPS, renders the area map,
  // and dynamically delivers situational messages without navigating away.
  // When in or near Sri Lanka hospitals, it highlights the facility.
  // When outside predefined facilities, it detects the real area name and
  // delivers 6 universal accessibility communication cards.
  // =========================================================================

  function applyDetectedLocation(data, accuracy = 5) {
    const locTitle = document.getElementById('location-title');
    const locSub = document.getElementById('location-gps-sub');
    const locEyebrow = document.getElementById('location-eyebrow');
    const avatar = document.getElementById('location-pin-avatar');
    const badgeIcon = document.getElementById('location-badge-icon');
    const liveBadgeText = document.getElementById('live-badge-text');

    const isPredefined = data.is_predefined === true;
    const placeName = data.poi_name || data.location_name || 'Detected Location';
    const facilityName = data.location_name || 'Facility';
    const areaName = data.area_name || placeName;
    const isHospital = data.detected_slug === 'hospital' || data.is_hospital === true;
    const isBank = data.detected_slug === 'bank' || data.is_bank === true;
    const isRestaurant = data.detected_slug === 'restaurant' || data.is_restaurant === true;
    const isSupermarket = data.detected_slug === 'supermarket' || data.is_supermarket === true;

    // 1. Update Hero Card
    if (data.manually_selected) {
      if (locTitle) locTitle.textContent = placeName;
      if (locEyebrow) {
        if (isHospital) locEyebrow.textContent = `HOSPITAL SELECTED FROM MAP • සිතියමෙන් තෝරාගත් රෝහල`;
        else if (isBank) locEyebrow.textContent = `BANK SELECTED FROM MAP • සිතියමෙන් තෝරාගත් බැංකුව`;
        else if (isRestaurant) locEyebrow.textContent = `RESTAURANT SELECTED FROM MAP • සිතියමෙන් තෝරාගත් ආපනශාලාව`;
        else if (isSupermarket) locEyebrow.textContent = `SUPERMARKET SELECTED FROM MAP • සිතියමෙන් තෝරාගත් සුපිරි වෙළඳසැල`;
        else locEyebrow.textContent = `SELECTED FROM MAP • සිතියමෙන් තෝරාගත් ස්ථානය`;
      }
      if (locSub) locSub.textContent = data.address || (isHospital ? `Selected on map • Hospital communication ready` : (isBank ? `Selected on map • Bank communication ready` : (isRestaurant ? `Selected on map • Restaurant communication ready` : (isSupermarket ? `Selected on map • Supermarket communication ready` : `Selected on map`))));
      if (liveBadgeText) liveBadgeText.textContent = isHospital ? `MAP • HOSPITAL` : (isBank ? `MAP • BANK` : (isRestaurant ? `MAP • RESTAURANT` : (isSupermarket ? `MAP • SUPERMARKET` : `MAP • VENUE`)));
    } else if (isPredefined) {
      if (locTitle) locTitle.textContent = placeName;
      if (locEyebrow) {
        if (isHospital) locEyebrow.textContent = `GPS DETECTED HOSPITAL • රෝහල හඳුනා ගන්නා ලදී`;
        else if (isBank) locEyebrow.textContent = `GPS DETECTED BANK • බැංකුව හඳුනා ගන්නා ලදී`;
        else if (isRestaurant) locEyebrow.textContent = `GPS DETECTED RESTAURANT • ආපනශාලාව හඳුනා ගන්නා ලදී`;
        else if (isSupermarket) locEyebrow.textContent = `GPS DETECTED SUPERMARKET • සුපිරි වෙළඳසැල හඳුනා ගන්නා ලදී`;
        else locEyebrow.textContent = `GPS DETECTED VENUE • ${facilityName.toUpperCase()}`;
      }
      if (locSub) locSub.textContent = data.address || `GPS Lock • Accuracy ±${Math.round(accuracy)}m`;
      if (liveBadgeText) liveBadgeText.textContent = isHospital ? `LIVE • HOSPITAL` : (isBank ? `LIVE • BANK` : (isRestaurant ? `LIVE • RESTAURANT` : (isSupermarket ? `LIVE • SUPERMARKET` : `LIVE • ${facilityName.toUpperCase()}`)));
    } else {
      // User is OUTSIDE predefined facilities
      if (locTitle) locTitle.textContent = areaName;
      if (locEyebrow) locEyebrow.textContent = `GPS AREA LOCATION • OUTSIDE VENUE`;
      if (locSub) locSub.textContent = data.address ? `Near ${data.address} • Venue scanning active` : `GPS Coordinates Lock (±${Math.round(accuracy)}m) • Ready to detect hospital, bank, restaurant, or supermarket`;
      if (liveBadgeText) liveBadgeText.textContent = `LIVE • SCANNING`;
    }

    if (avatar) {
      if (isSupermarket) {
        avatar.classList.add('is-supermarket');
        avatar.classList.remove('is-bank', 'is-restaurant');
      } else if (isRestaurant) {
        avatar.classList.add('is-restaurant');
        avatar.classList.remove('is-bank', 'is-supermarket');
      } else if (isBank) {
        avatar.classList.add('is-bank');
        avatar.classList.remove('is-restaurant', 'is-supermarket');
      } else {
        avatar.classList.remove('is-restaurant', 'is-bank', 'is-supermarket');
      }
      if (data.theme_color) avatar.style.color = data.theme_color;
      if (data.bg_color) avatar.style.background = data.bg_color;
    }
    if (badgeIcon && data.badge_icon) {
      badgeIcon.className = `fa-solid ${data.badge_icon}`;
    }

    // 2. Hospital / Bank / Restaurant / Supermarket Detection vs Waiting State Message Delivery
    const waitingCard = document.getElementById('waiting-hospital-state');
    const categorySection = document.getElementById('section-category-criteria');
    const hospitalCategoryBar = document.getElementById('category-selector-bar');
    const bankCategoryBar = document.getElementById('bank-category-selector-bar');
    const restaurantCategoryBar = document.getElementById('restaurant-category-selector-bar');
    const supermarketCategoryBar = document.getElementById('supermarket-category-selector-bar');
    const hospitalBadge = document.getElementById('hospital-status-badge');
    const sectionHeading = document.getElementById('section-messages-heading');
    const messagesGrid = document.getElementById('messages-grid');

    if (isHospital) {
      backToFirstScreen();
      currentActiveHospitalCategory = null;

      if (waitingCard) {
        waitingCard.classList.add('waiting-hidden');
        waitingCard.style.display = 'none';
      }
      if (categorySection) {
        categorySection.classList.remove('category-criteria-hidden');
        categorySection.classList.add('category-criteria-shown');
        categorySection.style.display = 'block';
      }
      if (bankCategoryBar) {
        bankCategoryBar.classList.add('bar-hidden');
        bankCategoryBar.style.display = 'none';
      }
      if (restaurantCategoryBar) {
        restaurantCategoryBar.classList.add('bar-hidden');
        restaurantCategoryBar.style.display = 'none';
      }
      if (supermarketCategoryBar) {
        supermarketCategoryBar.classList.add('bar-hidden');
        supermarketCategoryBar.style.display = 'none';
      }
      if (hospitalCategoryBar) {
        hospitalCategoryBar.classList.remove('bar-hidden');
        hospitalCategoryBar.style.display = 'flex';
        hospitalCategoryBar.style.flexDirection = 'column';
      }
      if (hospitalBadge) {
        hospitalBadge.classList.remove('badge-bank-theme', 'badge-restaurant-theme', 'badge-supermarket-theme');
        hospitalBadge.style.display = 'inline-flex';
        hospitalBadge.innerHTML = '<i class="fa-solid fa-square-h"></i> 9 Categories';
        hospitalBadge.style.background = '#fee2e2';
        hospitalBadge.style.color = '#ef4444';
      }
      if (sectionHeading) {
        sectionHeading.innerHTML = '<i class="fa-solid fa-list-check" style="color: #ef4444; margin-right: 6px;"></i> Hospital Message Criteria / රෝහල් කාණ්ඩ';
      }

      // Highlight map pill and pin if in hospital
      let targetHospId = '';
      if (data.hospital_info && data.hospital_info.id) {
        targetHospId = data.hospital_info.id;
      } else {
        const found = allHospitalsData.find(h => h.name.toLowerCase().includes(placeName.toLowerCase()) || (h.short_name && placeName.toLowerCase().includes(h.short_name.toLowerCase())));
        if (found) targetHospId = found.id;
      }
      if (targetHospId) {
        document.querySelectorAll('.map-hospital-pill-btn').forEach(btn => {
          if (btn.getAttribute('data-id') === targetHospId) {
            btn.classList.add('active-hospital-pill');
            btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
          } else {
            btn.classList.remove('active-hospital-pill');
          }
        });
        document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
        const targetPin = document.getElementById(`map-pin-${targetHospId}`);
        if (targetPin) targetPin.classList.add('selected-map-pin');
      }

      // Sync backend returned categories into cache
      if (data.hospital_categories) {
        ALL_HOSPITAL_CAT_KEYS.forEach(k => {
          if (Array.isArray(data.hospital_categories[k])) {
            cachedHospitalCategories[k] = data.hospital_categories[k];
          }
        });
      }
      if (Array.isArray(data.messages) && data.messages.length > 0) {
        cachedHospitalCategories['basic-comm'] = data.messages;
      }

      // Update count badge numbers on all 9 criteria buttons
      ALL_HOSPITAL_CAT_KEYS.forEach(k => {
        const meta = HOSPITAL_CATEGORY_METADATA[k];
        if (meta && meta.badgeId) {
          const badgeEl = document.getElementById(meta.badgeId);
          if (badgeEl && cachedHospitalCategories[k]) {
            badgeEl.textContent = cachedHospitalCategories[k].length;
          }
        }
      });

      const hintText = document.getElementById('category-hint-text');
      if (hintText) {
        hintText.style.display = 'block';
        hintText.innerHTML = '<i class="fa-solid fa-hand-pointer"></i> Press a category button above to suggest communication messages';
      }
    } else if (isBank) {
      backToFirstScreen();
      currentActiveHospitalCategory = null;

      if (waitingCard) {
        waitingCard.classList.add('waiting-hidden');
        waitingCard.style.display = 'none';
      }
      if (categorySection) {
        categorySection.classList.remove('category-criteria-hidden');
        categorySection.classList.add('category-criteria-shown');
        categorySection.style.display = 'block';
      }
      if (hospitalCategoryBar) {
        hospitalCategoryBar.classList.add('bar-hidden');
        hospitalCategoryBar.style.display = 'none';
      }
      if (restaurantCategoryBar) {
        restaurantCategoryBar.classList.add('bar-hidden');
        restaurantCategoryBar.style.display = 'none';
      }
      if (supermarketCategoryBar) {
        supermarketCategoryBar.classList.add('bar-hidden');
        supermarketCategoryBar.style.display = 'none';
      }
      if (bankCategoryBar) {
        bankCategoryBar.classList.remove('bar-hidden');
        bankCategoryBar.style.display = 'flex';
        bankCategoryBar.style.flexDirection = 'column';
      }
      if (hospitalBadge) {
        hospitalBadge.classList.remove('badge-restaurant-theme', 'badge-supermarket-theme');
        hospitalBadge.classList.add('badge-bank-theme');
        hospitalBadge.style.display = 'inline-flex';
        hospitalBadge.innerHTML = '<i class="fa-solid fa-building-columns"></i> 10 Categories';
        hospitalBadge.style.background = '#dbeafe';
        hospitalBadge.style.color = '#2563eb';
      }
      if (sectionHeading) {
        sectionHeading.innerHTML = '<i class="fa-solid fa-building-columns" style="color: #2563eb; margin-right: 6px;"></i> Bank Message Criteria / බැංකු කාණ්ඩ';
      }

      // Highlight map pill and pin if in bank
      let targetBankId = '';
      if (data.bank_info && data.bank_info.id) {
        targetBankId = data.bank_info.id;
      } else {
        const found = allBanksData.find(b => b.name.toLowerCase().includes(placeName.toLowerCase()) || (b.short_name && placeName.toLowerCase().includes(b.short_name.toLowerCase())));
        if (found) targetBankId = found.id;
      }
      if (targetBankId) {
        document.querySelectorAll('.map-bank-pill-btn').forEach(btn => {
          if (btn.getAttribute('data-id') === targetBankId) {
            btn.classList.add('active-bank-pill');
            btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
          } else {
            btn.classList.remove('active-bank-pill');
          }
        });
        document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
        const targetPin = document.getElementById(`map-pin-${targetBankId}`);
        if (targetPin) targetPin.classList.add('selected-map-pin');
      }

      // Sync backend returned bank categories into cache
      if (data.bank_categories) {
        ALL_BANK_CAT_KEYS.forEach(k => {
          if (Array.isArray(data.bank_categories[k])) {
            cachedBankCategories[k] = data.bank_categories[k];
          }
        });
      }

      // Update count badge numbers on bank criteria buttons
      ALL_BANK_CAT_KEYS.forEach(k => {
        const meta = BANK_CATEGORY_METADATA[k];
        if (meta && meta.badgeId) {
          const badgeEl = document.getElementById(meta.badgeId);
          if (badgeEl && cachedBankCategories[k]) {
            badgeEl.textContent = cachedBankCategories[k].length;
          }
        }
      });

      const hintText = document.getElementById('category-hint-text');
      if (hintText) {
        hintText.style.display = 'block';
        hintText.innerHTML = '<i class="fa-solid fa-hand-pointer"></i> Press a category button above to suggest communication messages';
      }
    } else if (isRestaurant) {
      backToFirstScreen();
      currentActiveHospitalCategory = null;

      if (waitingCard) {
        waitingCard.classList.add('waiting-hidden');
        waitingCard.style.display = 'none';
      }
      if (categorySection) {
        categorySection.classList.remove('category-criteria-hidden');
        categorySection.classList.add('category-criteria-shown');
        categorySection.style.display = 'block';
      }
      if (hospitalCategoryBar) {
        hospitalCategoryBar.classList.add('bar-hidden');
        hospitalCategoryBar.style.display = 'none';
      }
      if (bankCategoryBar) {
        bankCategoryBar.classList.add('bar-hidden');
        bankCategoryBar.style.display = 'none';
      }
      if (supermarketCategoryBar) {
        supermarketCategoryBar.classList.add('bar-hidden');
        supermarketCategoryBar.style.display = 'none';
      }
      if (restaurantCategoryBar) {
        restaurantCategoryBar.classList.remove('bar-hidden');
        restaurantCategoryBar.style.display = 'flex';
        restaurantCategoryBar.style.flexDirection = 'column';
      }
      if (hospitalBadge) {
        hospitalBadge.classList.remove('badge-bank-theme', 'badge-supermarket-theme');
        hospitalBadge.classList.add('badge-restaurant-theme');
        hospitalBadge.style.display = 'inline-flex';
        hospitalBadge.innerHTML = '<i class="fa-solid fa-utensils"></i> 9 Categories';
        hospitalBadge.style.background = '#fef3c7';
        hospitalBadge.style.color = '#d97706';
      }
      if (sectionHeading) {
        sectionHeading.innerHTML = '<i class="fa-solid fa-utensils" style="color: #f59e0b; margin-right: 6px;"></i> Restaurant Message Criteria / ආපනශාලා කාණ්ඩ';
      }

      // Highlight map pill and pin if in restaurant
      let targetRestId = '';
      if (data.restaurant_info && data.restaurant_info.id) {
        targetRestId = data.restaurant_info.id;
      } else {
        const found = allRestaurantsData.find(r => r.name.toLowerCase().includes(placeName.toLowerCase()) || (r.short_name && placeName.toLowerCase().includes(r.short_name.toLowerCase())));
        if (found) targetRestId = found.id;
      }
      if (targetRestId) {
        document.querySelectorAll('.map-restaurant-pill-btn').forEach(btn => {
          if (btn.getAttribute('data-id') === targetRestId) {
            btn.classList.add('active-restaurant-pill');
            btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
          } else {
            btn.classList.remove('active-restaurant-pill');
          }
        });
        document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
        const targetPin = document.getElementById(`map-pin-${targetRestId}`);
        if (targetPin) targetPin.classList.add('selected-map-pin');
      }

      // Sync backend returned restaurant categories into cache
      if (data.restaurant_categories) {
        ALL_RESTAURANT_CAT_KEYS.forEach(k => {
          if (Array.isArray(data.restaurant_categories[k])) {
            cachedRestaurantCategories[k] = data.restaurant_categories[k];
          }
        });
      }

      // Update count badge numbers on restaurant criteria buttons
      ALL_RESTAURANT_CAT_KEYS.forEach(k => {
        const meta = RESTAURANT_CATEGORY_METADATA[k];
        if (meta && meta.badgeId) {
          const badgeEl = document.getElementById(meta.badgeId);
          if (badgeEl && cachedRestaurantCategories[k]) {
            badgeEl.textContent = cachedRestaurantCategories[k].length;
          }
        }
      });

      const hintText = document.getElementById('category-hint-text');
      if (hintText) {
        hintText.style.display = 'block';
        hintText.innerHTML = '<i class="fa-solid fa-hand-pointer"></i> Press a category button above to suggest communication messages';
      }
    } else if (isSupermarket) {
      backToFirstScreen();
      currentActiveHospitalCategory = null;

      if (waitingCard) {
        waitingCard.classList.add('waiting-hidden');
        waitingCard.style.display = 'none';
      }
      if (categorySection) {
        categorySection.classList.remove('category-criteria-hidden');
        categorySection.classList.add('category-criteria-shown');
        categorySection.style.display = 'block';
      }
      if (hospitalCategoryBar) {
        hospitalCategoryBar.classList.add('bar-hidden');
        hospitalCategoryBar.style.display = 'none';
      }
      if (bankCategoryBar) {
        bankCategoryBar.classList.add('bar-hidden');
        bankCategoryBar.style.display = 'none';
      }
      if (restaurantCategoryBar) {
        restaurantCategoryBar.classList.add('bar-hidden');
        restaurantCategoryBar.style.display = 'none';
      }
      if (supermarketCategoryBar) {
        supermarketCategoryBar.classList.remove('bar-hidden');
        supermarketCategoryBar.style.display = 'flex';
        supermarketCategoryBar.style.flexDirection = 'column';
      }
      if (hospitalBadge) {
        hospitalBadge.classList.remove('badge-bank-theme', 'badge-restaurant-theme');
        hospitalBadge.classList.add('badge-supermarket-theme');
        hospitalBadge.style.display = 'inline-flex';
        hospitalBadge.innerHTML = '<i class="fa-solid fa-cart-shopping"></i> 9 Categories';
        hospitalBadge.style.background = '#d1fae5';
        hospitalBadge.style.color = '#059669';
      }
      if (sectionHeading) {
        sectionHeading.innerHTML = '<i class="fa-solid fa-cart-shopping" style="color: #10b981; margin-right: 6px;"></i> Supermarket Message Criteria / සුපිරි වෙළඳසැල් කාණ්ඩ';
      }

      // Highlight map pill and pin if in supermarket
      let targetSmId = '';
      if (data.supermarket_info && data.supermarket_info.id) {
        targetSmId = data.supermarket_info.id;
      } else {
        const found = allSupermarketsData.find(s => s.name.toLowerCase().includes(placeName.toLowerCase()) || (s.short_name && placeName.toLowerCase().includes(s.short_name.toLowerCase())));
        if (found) targetSmId = found.id;
      }
      if (targetSmId) {
        document.querySelectorAll('.map-supermarket-pill-btn').forEach(btn => {
          if (btn.getAttribute('data-id') === targetSmId) {
            btn.classList.add('active-supermarket-pill');
            btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
          } else {
            btn.classList.remove('active-supermarket-pill');
          }
        });
        document.querySelectorAll('.map-hospital-pin, .map-bank-pin, .map-restaurant-pin, .map-supermarket-pin').forEach(p => p.classList.remove('selected-map-pin'));
        const targetPin = document.getElementById(`map-pin-${targetSmId}`);
        if (targetPin) targetPin.classList.add('selected-map-pin');
      }

      // Sync backend returned supermarket categories into cache
      if (data.supermarket_categories) {
        ALL_SUPERMARKET_CAT_KEYS.forEach(k => {
          if (Array.isArray(data.supermarket_categories[k])) {
            cachedSupermarketCategories[k] = data.supermarket_categories[k];
          }
        });
      }

      // Update count badge numbers on supermarket criteria buttons
      ALL_SUPERMARKET_CAT_KEYS.forEach(k => {
        const meta = SUPERMARKET_CATEGORY_METADATA[k];
        if (meta && meta.badgeId) {
          const badgeEl = document.getElementById(meta.badgeId);
          if (badgeEl && cachedSupermarketCategories[k]) {
            badgeEl.textContent = cachedSupermarketCategories[k].length;
          }
        }
      });

      const hintText = document.getElementById('category-hint-text');
      if (hintText) {
        hintText.style.display = 'block';
        hintText.innerHTML = '<i class="fa-solid fa-hand-pointer"></i> Press a category button above to suggest communication messages';
      }
    } else {
      // User is NOT in hospital, bank, restaurant, or supermarket: hide categories, show waiting card
      backToFirstScreen();
      currentActiveHospitalCategory = null;

      if (waitingCard) {
        waitingCard.classList.remove('waiting-hidden');
        waitingCard.style.display = 'block';
        const waitingDesc = waitingCard.querySelector('.waiting-desc');
        if (waitingDesc) {
          waitingDesc.innerHTML = `Currently at <strong>${placeName || areaName}</strong>. Select a hospital (🔴), bank (🔵), restaurant (🟠), or supermarket (🟢) on the map, or wait for GPS to detect your venue.`;
        }
      }
      if (categorySection) {
        categorySection.classList.remove('category-criteria-shown');
        categorySection.classList.add('category-criteria-hidden');
        categorySection.style.display = 'none';
      }
      if (hospitalCategoryBar) {
        hospitalCategoryBar.classList.add('bar-hidden');
        hospitalCategoryBar.style.display = 'none';
      }
      if (bankCategoryBar) {
        bankCategoryBar.classList.add('bar-hidden');
        bankCategoryBar.style.display = 'none';
      }
      if (restaurantCategoryBar) {
        restaurantCategoryBar.classList.add('bar-hidden');
        restaurantCategoryBar.style.display = 'none';
      }
      if (supermarketCategoryBar) {
        supermarketCategoryBar.classList.add('bar-hidden');
        supermarketCategoryBar.style.display = 'none';
      }
      if (hospitalBadge) hospitalBadge.style.display = 'none';
      if (messagesGrid) {
        messagesGrid.innerHTML = '';
        messagesGrid.style.display = 'none';
      }
    }

    // 3. Update Area Map Widget with User Position
    const lat = typeof data.lat === 'number' ? data.lat : (currentCoordinates ? currentCoordinates.lat : null);
    const lon = typeof data.lon === 'number' ? data.lon : (currentCoordinates ? currentCoordinates.lon : null);

    if (lat !== null && lon !== null && areaMap && typeof L !== 'undefined') {
      currentCoordinates = { lat, lon, accuracy };

      const userPulseIcon = L.divIcon({
        className: 'gps-user-pulse-marker',
        iconSize: [18, 18],
        iconAnchor: [9, 9],
        popupAnchor: [0, -10]
      });

      if (!userGpsMarker) {
        userGpsMarker = L.marker([lat, lon], { icon: userPulseIcon, zIndexOffset: 1000 }).addTo(areaMap);
      } else {
        userGpsMarker.setLatLng([lat, lon]);
      }

      const popupTitle = isPredefined ? placeName : areaName;
      const popupSubtitle = isPredefined ? `Inside ${facilityName}` : 'Outside predefined facilities (Everyday Area)';
      userGpsMarker.bindPopup(`
        <div style="font-family: inherit; font-size: 12px; line-height: 1.4;">
          <strong style="color: ${data.theme_color || '#2563eb'};">
            <i class="fa-solid fa-crosshairs"></i> ${popupTitle}
          </strong><br>
          <span style="color: #64748b; font-size: 11px;">${popupSubtitle} • Accuracy ±${Math.round(accuracy)}m</span>
        </div>
      `);

      if (!userAccuracyCircle) {
        userAccuracyCircle = L.circle([lat, lon], {
          radius: Math.max(accuracy, 20),
          color: isPredefined ? (data.theme_color || '#2563eb') : '#6366f1',
          fillColor: isPredefined ? (data.theme_color || '#2563eb') : '#6366f1',
          fillOpacity: 0.12,
          weight: 1.5
        }).addTo(areaMap);
      } else {
        userAccuracyCircle.setLatLng([lat, lon]);
        userAccuracyCircle.setRadius(Math.max(accuracy, 20));
        userAccuracyCircle.setStyle({
          color: isPredefined ? (data.theme_color || '#2563eb') : '#6366f1',
          fillColor: isPredefined ? (data.theme_color || '#2563eb') : '#6366f1'
        });
      }

      areaMap.setView([lat, lon], 15, { animate: true });
      setTimeout(() => {
        if (areaMap) areaMap.invalidateSize();
      }, 150);
    }

    // Refresh Sri Lanka hospitals if returned in backend payload
    if (data.sri_lanka_hospitals && Array.isArray(data.sri_lanka_hospitals)) {
      allHospitalsData = data.sri_lanka_hospitals;
      renderSriLankaHospitals(allHospitalsData);
    }

    // Refresh Sri Lanka banks if returned in backend payload
    if (data.sri_lanka_banks && Array.isArray(data.sri_lanka_banks)) {
      allBanksData = data.sri_lanka_banks;
      renderSriLankaBanks(allBanksData);
    }

    // Refresh Sri Lanka restaurants if returned in backend payload
    if (data.sri_lanka_restaurants && Array.isArray(data.sri_lanka_restaurants)) {
      allRestaurantsData = data.sri_lanka_restaurants;
      renderSriLankaRestaurants(allRestaurantsData);
    }

    // Refresh Sri Lanka supermarkets if returned in backend payload
    if (data.sri_lanka_supermarkets && Array.isArray(data.sri_lanka_supermarkets)) {
      allSupermarketsData = data.sri_lanka_supermarkets;
      renderSriLankaSupermarkets(allSupermarketsData);
    }

    // 4. Update Map Status Bar and Live Status Tag
    const mapStatusBar = document.getElementById('map-status-bar');
    const mapStatusIcon = document.getElementById('map-status-icon');
    const mapStatusText = document.getElementById('map-status-text');
    const mapLiveStatusTag = document.getElementById('map-live-status-tag');

    if (isPredefined) {
      if (mapStatusBar) {
        mapStatusBar.classList.add('status-inside');
        mapStatusBar.classList.remove('status-outside');
      }
      if (mapStatusIcon) {
        mapStatusIcon.className = 'fa-solid fa-circle-check';
        mapStatusIcon.style.color = data.theme_color || '#10b981';
      }
      if (mapStatusText) {
        mapStatusText.textContent = `Inside ${facilityName}: ${placeName}`;
      }
      if (mapLiveStatusTag) {
        mapLiveStatusTag.textContent = `Inside ${facilityName}`;
        mapLiveStatusTag.style.color = data.theme_color || '#2563eb';
      }
    } else {
      if (mapStatusBar) {
        mapStatusBar.classList.add('status-outside');
        mapStatusBar.classList.remove('status-inside');
      }
      if (mapStatusIcon) {
        mapStatusIcon.className = 'fa-solid fa-circle-info';
        mapStatusIcon.style.color = '#6366f1';
      }
      if (mapStatusText) {
        mapStatusText.textContent = `Current Area (${areaName}). Tap red pin for hospital, blue pin for bank, orange pin for restaurant, or green pin for supermarket.`;
      }
      if (mapLiveStatusTag) {
        mapLiveStatusTag.textContent = `Select Hospital / Bank / Dining / Supermarket on Map`;
        mapLiveStatusTag.style.color = '#6366f1';
      }
    }

    // 5. Update Sub-Header Strip
    if (gpsStripStatus) {
      if (isPredefined) {
        gpsStripStatus.textContent = `GPS Locked: ${placeName} (±${Math.round(accuracy)}m)`;
      } else {
        gpsStripStatus.textContent = `GPS: Outside predefined venues (${areaName})`;
      }
    }

    // 6. Update Drawer Active Item
    const detectedSlug = data.detected_slug || 'other';
    document.querySelectorAll('.drawer-link.gps-sim-btn').forEach(btn => {
      if (btn.getAttribute('data-slug') === detectedSlug) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });

    // 7. Toast Feedback
    if (data.manually_selected && data.is_supermarket) {
      showGpsToast(`🛒 Selected Supermarket from Map: ${placeName}`, 3200);
    } else if (data.is_supermarket) {
      showGpsToast(`🛒 Detected Supermarket via GPS: ${placeName}`, 3200);
    } else if (data.manually_selected && data.is_restaurant) {
      showGpsToast(`🍽️ Selected Restaurant from Map: ${placeName}`, 3200);
    } else if (data.is_restaurant) {
      showGpsToast(`🍽️ Detected Restaurant via GPS: ${placeName}`, 3200);
    } else if (data.manually_selected && data.is_bank) {
      showGpsToast(`🏦 Selected Bank from Map: ${placeName}`, 3200);
    } else if (data.is_bank) {
      showGpsToast(`🏦 Detected Bank via GPS: ${placeName}`, 3200);
    } else if (data.manually_selected) {
      showGpsToast(`🏥 Selected Hospital from Map: ${placeName}. Press a category button to suggest messages.`, 3200);
    } else if (isHospital) {
      showGpsToast(`🏥 Detected Hospital via GPS: ${placeName}. Press a category button to suggest messages.`, 3200);
    } else if (isPredefined) {
      showGpsToast(`📍 Detected ${facilityName}`, 2800);
    } else {
      showGpsToast(`📍 Area: ${areaName}. Tap red (hospital), blue (bank), orange (restaurant), or green (supermarket) pin.`, 3000);
    }
  }

  // Detect Live Device GPS Coordinates
  async function detectDeviceGps(silent = false) {
    if (!silent) closeGpsDialog();
    showGpsToast("Acquiring GPS satellite coordinates...", 0);

    if (gpsStripStatus) {
      gpsStripStatus.textContent = "GPS Active: Acquiring satellite lock...";
    }

    if (!navigator.geolocation) {
      showGpsToast("GPS geolocation not available on this device.", 3000);
      return;
    }

    navigator.geolocation.getCurrentPosition(
      async (position) => {
        const lat = position.coords.latitude;
        const lon = position.coords.longitude;
        const accuracy = position.coords.accuracy || 10;
        showGpsToast(`Coordinates acquired (${lat.toFixed(4)}, ${lon.toFixed(4)}). Detecting facility...`, 0);

        try {
          const resp = await fetch('/api/detect-location', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ lat, lon })
          });

          if (resp.ok) {
            const data = await resp.json();
            applyDetectedLocation(data, accuracy);

            // Fetch Sri Lanka hospitals, banks, restaurants & supermarkets sorted by distance from current GPS position
            fetchNearbySriLankaHospitals(lat, lon);
            fetchNearbySriLankaBanks(lat, lon);
            fetchNearbySriLankaRestaurants(lat, lon);
            fetchNearbySriLankaSupermarkets(lat, lon);
          } else {
            showGpsToast("Location detection server returned an error.", 2500);
          }
        } catch (err) {
          console.error("Location detection error:", err);
          showGpsToast("Network error querying location services.", 2500);
        }
      },
      (error) => {
        console.warn("Geolocation acquisition error:", error);
        if (!silent) {
          showGpsToast("GPS permission denied or timed out. You can use GPS Simulator below.", 3500);
        }
        if (gpsStripStatus) {
          gpsStripStatus.textContent = "GPS: Waiting for satellite coordinates / simulator";
        }
      },
      { enableHighAccuracy: true, timeout: 6000 }
    );
  }

  // Fetch Sri Lanka hospitals sorted by distance
  async function fetchNearbySriLankaHospitals(lat, lon) {
    try {
      const res = await fetch(`/api/sri-lanka-hospitals?lat=${lat}&lon=${lon}`);
      if (res.ok) {
        const payload = await res.json();
        if (payload.hospitals && payload.hospitals.length > 0) {
          allHospitalsData = payload.hospitals;
          renderSriLankaHospitals(allHospitalsData);
        }
      }
    } catch (e) {
      console.warn("Could not fetch distance-sorted hospitals:", e);
    }
  }

  // Fetch Sri Lanka banks sorted by distance
  async function fetchNearbySriLankaBanks(lat, lon) {
    try {
      const res = await fetch(`/api/sri-lanka-banks?lat=${lat}&lon=${lon}`);
      if (res.ok) {
        const payload = await res.json();
        if (payload.banks && payload.banks.length > 0) {
          allBanksData = payload.banks;
          renderSriLankaBanks(allBanksData);
        }
      }
    } catch (e) {
      console.warn("Could not fetch distance-sorted banks:", e);
    }
  }

  // Fetch Sri Lanka restaurants sorted by distance
  async function fetchNearbySriLankaRestaurants(lat, lon) {
    try {
      const res = await fetch(`/api/sri-lanka-restaurants?lat=${lat}&lon=${lon}`);
      if (res.ok) {
        const payload = await res.json();
        if (payload.restaurants && payload.restaurants.length > 0) {
          allRestaurantsData = payload.restaurants;
          renderSriLankaRestaurants(allRestaurantsData);
        }
      }
    } catch (e) {
      console.warn("Could not fetch distance-sorted restaurants:", e);
    }
  }

  // Fetch Sri Lanka supermarkets sorted by distance
  async function fetchNearbySriLankaSupermarkets(lat, lon) {
    try {
      const res = await fetch(`/api/sri-lanka-supermarkets?lat=${lat}&lon=${lon}`);
      if (res.ok) {
        const payload = await res.json();
        if (payload.supermarkets && payload.supermarkets.length > 0) {
          allSupermarketsData = payload.supermarkets;
          renderSriLankaSupermarkets(allSupermarketsData);
        }
      }
    } catch (e) {
      console.warn("Could not fetch distance-sorted supermarkets:", e);
    }
  }

  // Manually select a hospital (by ID, coordinates, or name)
  async function manuallySelectHospital(hospitalId, lat, lon, name) {
    closeGpsDialog();
    if (drawerBackdrop) drawerBackdrop.classList.remove('open');
    switchTab('home');

    // Find hospital details if ID is provided
    let matchedHosp = null;
    if (hospitalId) {
      matchedHosp = allHospitalsData.find(h => h.id === hospitalId) || SRI_LANKA_HOSPITALS_DATA.find(h => h.id === hospitalId);
    }
    if (!matchedHosp && name) {
      const nl = name.toLowerCase();
      matchedHosp = allHospitalsData.find(h => h.name.toLowerCase().includes(nl) || (h.short_name && h.short_name.toLowerCase().includes(nl)));
    }

    const targetLat = typeof lat === 'number' ? lat : (matchedHosp ? matchedHosp.lat : 6.9197);
    const targetLon = typeof lon === 'number' ? lon : (matchedHosp ? matchedHosp.lon : 79.8693);
    const targetName = name || (matchedHosp ? matchedHosp.name : 'Selected Hospital');
    const targetId = hospitalId || (matchedHosp ? matchedHosp.id : 'nhsl-colombo');

    showGpsToast(`🏥 Selecting ${targetName}...`, 0);
    if (gpsStripStatus) {
      gpsStripStatus.textContent = `Hospital Selected: ${targetName}`;
    }

    try {
      const resp = await fetch('/api/select-hospital', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ hospital_id: targetId, lat: targetLat, lon: targetLon, name: targetName })
      });

      if (resp.ok) {
        const data = await resp.json();
        data.manually_selected = true;
        setTimeout(() => {
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }, 150);
      } else {
        const fbResp = await fetch('/api/detect-location', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ lat: targetLat, lon: targetLon })
        });
        if (fbResp.ok) {
          const data = await fbResp.json();
          data.manually_selected = true;
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }
      }
    } catch (err) {
      console.error("Error manually selecting hospital:", err);
      showGpsToast("Error querying server for hospital selection.", 2500);
    }
  }

  // Manually select a bank (by ID, coordinates, or name)
  async function manuallySelectBank(bankId, lat, lon, name) {
    closeGpsDialog();
    if (drawerBackdrop) drawerBackdrop.classList.remove('open');
    switchTab('home');

    // Find bank details if ID is provided
    let matchedBank = null;
    if (bankId) {
      matchedBank = allBanksData.find(b => b.id === bankId) || SRI_LANKA_BANKS_DATA.find(b => b.id === bankId);
    }
    if (!matchedBank && name) {
      const nl = name.toLowerCase();
      matchedBank = allBanksData.find(b => b.name.toLowerCase().includes(nl) || (b.short_name && b.short_name.toLowerCase().includes(nl)));
    }

    const targetLat = typeof lat === 'number' ? lat : (matchedBank ? matchedBank.lat : 6.9348);
    const targetLon = typeof lon === 'number' ? lon : (matchedBank ? matchedBank.lon : 79.8436);
    const targetName = name || (matchedBank ? matchedBank.name : 'Selected Bank');
    const targetId = bankId || (matchedBank ? matchedBank.id : 'boc-head-office');

    showGpsToast(`🏦 Selecting ${targetName}...`, 0);
    if (gpsStripStatus) {
      gpsStripStatus.textContent = `Bank Selected: ${targetName}`;
    }

    try {
      const resp = await fetch('/api/select-bank', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ bank_id: targetId, lat: targetLat, lon: targetLon, name: targetName })
      });

      if (resp.ok) {
        const data = await resp.json();
        data.manually_selected = true;
        setTimeout(() => {
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }, 150);
      } else {
        const fbResp = await fetch('/api/detect-location', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ lat: targetLat, lon: targetLon })
        });
        if (fbResp.ok) {
          const data = await fbResp.json();
          data.manually_selected = true;
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }
      }
    } catch (err) {
      console.warn("Manual bank selection error:", err);
      showGpsToast(`🏦 Switched to ${targetName}`, 2500);
      if (gpsStripStatus) {
        gpsStripStatus.textContent = `Bank: ${targetName}`;
      }
    }
  }

  // Manually select a restaurant (by ID, coordinates, or name)
  async function manuallySelectRestaurant(restaurantId, lat, lon, name) {
    closeGpsDialog();
    if (drawerBackdrop) drawerBackdrop.classList.remove('open');
    switchTab('home');

    // Find restaurant details if ID is provided
    let matchedRest = null;
    if (restaurantId) {
      matchedRest = allRestaurantsData.find(r => r.id === restaurantId) || SRI_LANKA_RESTAURANTS_DATA.find(r => r.id === restaurantId);
    }
    if (!matchedRest && name) {
      const nl = name.toLowerCase();
      matchedRest = allRestaurantsData.find(r => r.name.toLowerCase().includes(nl) || (r.short_name && r.short_name.toLowerCase().includes(nl)));
    }

    const targetLat = typeof lat === 'number' ? lat : (matchedRest ? matchedRest.lat : 6.9115);
    const targetLon = typeof lon === 'number' ? lon : (matchedRest ? matchedRest.lon : 79.8635);
    const targetName = name || (matchedRest ? matchedRest.name : 'Selected Restaurant');
    const targetId = restaurantId || (matchedRest ? matchedRest.id : 'upalis-colombo');

    showGpsToast(`🍽️ Selecting ${targetName}...`, 0);
    if (gpsStripStatus) {
      gpsStripStatus.textContent = `Restaurant Selected: ${targetName}`;
    }

    try {
      const resp = await fetch('/api/select-restaurant', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ restaurant_id: targetId, lat: targetLat, lon: targetLon, name: targetName })
      });

      if (resp.ok) {
        const data = await resp.json();
        data.manually_selected = true;
        setTimeout(() => {
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }, 150);
      } else {
        const fbResp = await fetch('/api/detect-location', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ lat: targetLat, lon: targetLon })
        });
        if (fbResp.ok) {
          const data = await fbResp.json();
          data.manually_selected = true;
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }
      }
    } catch (err) {
      console.warn("Manual restaurant selection error:", err);
      showGpsToast(`🍽️ Switched to ${targetName}`, 2500);
      if (gpsStripStatus) {
        gpsStripStatus.textContent = `Restaurant: ${targetName}`;
      }
    }
  }

  // Manually select a supermarket (by ID, coordinates, or name)
  async function manuallySelectSupermarket(supermarketId, lat, lon, name) {
    closeGpsDialog();
    if (drawerBackdrop) drawerBackdrop.classList.remove('open');
    switchTab('home');

    // Find supermarket details if ID is provided
    let matchedSm = null;
    if (supermarketId) {
      matchedSm = allSupermarketsData.find(s => s.id === supermarketId) || SRI_LANKA_SUPERMARKETS_DATA.find(s => s.id === supermarketId);
    }
    if (!matchedSm && name) {
      const nl = name.toLowerCase();
      matchedSm = allSupermarketsData.find(s => s.name.toLowerCase().includes(nl) || (s.short_name && s.short_name.toLowerCase().includes(nl)));
    }

    const targetLat = typeof lat === 'number' ? lat : (matchedSm ? matchedSm.lat : 6.9180);
    const targetLon = typeof lon === 'number' ? lon : (matchedSm ? matchedSm.lon : 79.8620);
    const targetName = name || (matchedSm ? matchedSm.name : 'Selected Supermarket');
    const targetId = supermarketId || (matchedSm ? matchedSm.id : 'cargills-food-city-staple-street');

    showGpsToast(`🛒 Selecting ${targetName}...`, 0);
    if (gpsStripStatus) {
      gpsStripStatus.textContent = `Supermarket Selected: ${targetName}`;
    }

    try {
      const resp = await fetch('/api/select-supermarket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ supermarket_id: targetId, lat: targetLat, lon: targetLon, name: targetName })
      });

      if (resp.ok) {
        const data = await resp.json();
        data.manually_selected = true;
        setTimeout(() => {
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }, 150);
      } else {
        const fbResp = await fetch('/api/detect-location', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ lat: targetLat, lon: targetLon })
        });
        if (fbResp.ok) {
          const data = await fbResp.json();
          data.manually_selected = true;
          applyDetectedLocation(data, 5);
          if (areaMap) {
            areaMap.flyTo([targetLat, targetLon], 16, { animate: true, duration: 1 });
          }
        }
      }
    } catch (err) {
      console.warn("Manual supermarket selection error:", err);
      showGpsToast(`🛒 Switched to ${targetName}`, 2500);
      if (gpsStripStatus) {
        gpsStripStatus.textContent = `Supermarket: ${targetName}`;
      }
    }
  }

  function simulateHospitalCoordinates(lat, lon, name) {
    return manuallySelectHospital(null, lat, lon, name);
  }

  function simulateBankCoordinates(lat, lon, name) {
    return manuallySelectBank(null, lat, lon, name);
  }

  function simulateRestaurantCoordinates(lat, lon, name) {
    return manuallySelectRestaurant(null, lat, lon, name);
  }

  function simulateSupermarketCoordinates(lat, lon, name) {
    return manuallySelectSupermarket(null, lat, lon, name);
  }

  // Simulate generic venue coordinates
  async function simulateGpsLocation(slug) {
    closeGpsDialog();
    if (drawerBackdrop) drawerBackdrop.classList.remove('open');
    switchTab('home');

    const coords = REFERENCE_GPS_COORDINATES[slug] || REFERENCE_GPS_COORDINATES['other'];
    showGpsToast(`GPS moving to coordinates (${coords.lat.toFixed(3)}, ${coords.lon.toFixed(3)})...`, 0);

    if (gpsStripStatus) {
      gpsStripStatus.textContent = `GPS: Moving to ${coords.name}...`;
    }

    try {
      const resp = await fetch('/api/detect-location', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lat: coords.lat, lon: coords.lon })
      });

      if (resp.ok) {
        const data = await resp.json();
        setTimeout(() => {
          applyDetectedLocation(data, 3);
        }, 300);
      } else {
        showGpsToast("Failed to simulate GPS coordinates.", 2000);
      }
    } catch (err) {
      console.error(err);
      showGpsToast("Error querying detection server.", 2000);
    }
  }

  // Wire up GPS Buttons
  if (runLiveGpsBtn) runLiveGpsBtn.addEventListener('click', () => detectDeviceGps(false));
  if (previewLiveGpsBtn) previewLiveGpsBtn.addEventListener('click', () => detectDeviceGps(false));
  if (gpsStripRecheck) gpsStripRecheck.addEventListener('click', () => detectDeviceGps(false));

  // Wire up standard simulation buttons
  document.querySelectorAll('.gps-sim-btn, .gps-simulate-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const slug = btn.getAttribute('data-slug');
      if (slug) simulateGpsLocation(slug);
    });
  });

  // Wire up Sri Lanka Hospital simulation chips
  document.querySelectorAll('.gps-hospital-sim-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const lat = parseFloat(btn.getAttribute('data-lat'));
      const lon = parseFloat(btn.getAttribute('data-lon'));
      const name = btn.getAttribute('data-name');
      manuallySelectHospital(null, lat, lon, name);
    });
  });

  // Wire up Manual Hospital Selectors
  const manualHospitalSelect = document.getElementById('manual-hospital-select');
  const btnApplyManualHospital = document.getElementById('btn-apply-manual-hospital');
  if (manualHospitalSelect) {
    manualHospitalSelect.addEventListener('change', () => {
      const selectedId = manualHospitalSelect.value;
      if (selectedId) {
        manuallySelectHospital(selectedId);
      }
    });
  }
  if (btnApplyManualHospital) {
    btnApplyManualHospital.addEventListener('click', () => {
      const selectedId = manualHospitalSelect ? manualHospitalSelect.value : '';
      if (selectedId) {
        manuallySelectHospital(selectedId);
      } else {
        showGpsToast("Please choose a hospital from the list.", 2500);
      }
    });
  }

  const modalManualSelect = document.getElementById('modal-manual-hospital-select');
  const btnModalApplyHospital = document.getElementById('btn-modal-apply-hospital');
  if (modalManualSelect) {
    modalManualSelect.addEventListener('change', () => {
      const selectedId = modalManualSelect.value;
      if (selectedId) {
        manuallySelectHospital(selectedId);
      }
    });
  }
  if (btnModalApplyHospital) {
    btnModalApplyHospital.addEventListener('click', () => {
      const selectedId = modalManualSelect ? modalManualSelect.value : '';
      if (selectedId) {
        manuallySelectHospital(selectedId);
      } else {
        showGpsToast("Please choose a hospital from the list.", 2500);
      }
    });
  }

  const modalManualBankSelect = document.getElementById('modal-manual-bank-select');
  const btnModalApplyBank = document.getElementById('btn-modal-apply-bank');
  if (modalManualBankSelect) {
    modalManualBankSelect.addEventListener('change', () => {
      const selectedId = modalManualBankSelect.value;
      if (selectedId) {
        manuallySelectBank(selectedId);
      }
    });
  }
  if (btnModalApplyBank) {
    btnModalApplyBank.addEventListener('click', () => {
      const selectedId = modalManualBankSelect ? modalManualBankSelect.value : '';
      if (selectedId) {
        manuallySelectBank(selectedId);
      } else {
        showGpsToast("Please choose a bank from the list.", 2500);
      }
    });
  }

  // Wire up Sri Lanka Bank simulation chips
  document.querySelectorAll('.gps-bank-sim-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const lat = parseFloat(btn.getAttribute('data-lat'));
      const lon = parseFloat(btn.getAttribute('data-lon'));
      const name = btn.getAttribute('data-name');
      manuallySelectBank(id, lat, lon, name);
    });
  });

  // Wire up Manual Restaurant Selectors
  const modalManualRestaurantSelect = document.getElementById('modal-manual-restaurant-select');
  const btnModalApplyRestaurant = document.getElementById('btn-modal-apply-restaurant');
  if (modalManualRestaurantSelect) {
    modalManualRestaurantSelect.addEventListener('change', () => {
      const selectedId = modalManualRestaurantSelect.value;
      if (selectedId) {
        manuallySelectRestaurant(selectedId);
      }
    });
  }
  if (btnModalApplyRestaurant) {
    btnModalApplyRestaurant.addEventListener('click', () => {
      const selectedId = modalManualRestaurantSelect ? modalManualRestaurantSelect.value : '';
      if (selectedId) {
        manuallySelectRestaurant(selectedId);
      } else {
        showGpsToast("Please choose a restaurant from the list.", 2500);
      }
    });
  }

  // Wire up Sri Lanka Restaurant simulation chips
  document.querySelectorAll('.gps-restaurant-sim-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const lat = parseFloat(btn.getAttribute('data-lat'));
      const lon = parseFloat(btn.getAttribute('data-lon'));
      const name = btn.getAttribute('data-name');
      manuallySelectRestaurant(id, lat, lon, name);
    });
  });

  // Wire up Manual Supermarket Selectors
  const modalManualSupermarketSelect = document.getElementById('modal-manual-supermarket-select');
  const btnModalApplySupermarket = document.getElementById('btn-modal-apply-supermarket');
  if (modalManualSupermarketSelect) {
    modalManualSupermarketSelect.addEventListener('change', () => {
      const selectedId = modalManualSupermarketSelect.value;
      if (selectedId) {
        manuallySelectSupermarket(selectedId);
      }
    });
  }
  if (btnModalApplySupermarket) {
    btnModalApplySupermarket.addEventListener('click', () => {
      const selectedId = modalManualSupermarketSelect ? modalManualSupermarketSelect.value : '';
      if (selectedId) {
        manuallySelectSupermarket(selectedId);
      } else {
        showGpsToast("Please choose a supermarket from the list.", 2500);
      }
    });
  }

  // Wire up Sri Lanka Supermarket simulation chips
  document.querySelectorAll('.gps-supermarket-sim-chip').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const lat = parseFloat(btn.getAttribute('data-lat'));
      const lon = parseFloat(btn.getAttribute('data-lon'));
      const name = btn.getAttribute('data-name');
      manuallySelectSupermarket(id, lat, lon, name);
    });
  });

  // Frame View Toggle for Desktop Preview
  if (previewFrameToggle && phoneMockup) {
    previewFrameToggle.addEventListener('click', () => {
      phoneMockup.classList.toggle('fullscreen-mode');
      const isFull = phoneMockup.classList.contains('fullscreen-mode');
      previewFrameToggle.innerHTML = isFull 
        ? '<i class="fa-solid fa-mobile-screen"></i> Phone Frame' 
        : '<i class="fa-solid fa-expand"></i> Expanded View';
      setTimeout(() => {
        if (areaMap) areaMap.invalidateSize();
      }, 300);
    });
  }

  // Initialize Area Map
  initAreaMap();

  // 12. AUTO-START GPS DETECTION ON INITIAL APP LOAD
  if (navigator.geolocation) {
    detectDeviceGps(true);

    // Watch position continuously
    try {
      navigator.geolocation.watchPosition(
        async (position) => {
          const lat = position.coords.latitude;
          const lon = position.coords.longitude;
          try {
            const resp = await fetch('/api/detect-location', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ lat, lon })
            });
            if (resp.ok) {
              const data = await resp.json();
              if (data && data.success) {
                applyDetectedLocation(data, position.coords.accuracy || 10);
              }
            }
          } catch (e) {
            // Silently ignore background polling errors
          }
        },
        null,
        { enableHighAccuracy: true, maximumAge: 10000, timeout: 15000 }
      );
    } catch (e) {
      console.warn("watchPosition not supported or blocked:", e);
    }
  }
});

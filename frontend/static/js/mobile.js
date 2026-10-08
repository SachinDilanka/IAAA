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
  let currentCoordinates = null;
  let isMapExpanded = false;
  let allHospitalsData = [...SRI_LANKA_HOSPITALS_DATA];
  let allBanksData = [...SRI_LANKA_BANKS_DATA];
  let hospitalMarkersMap = {};
  let bankMarkersMap = {};

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
    'bank-reception-queue'
  ];

  // Screen 1 & Screen 2 Navigation:
  // First screen displays only the Map and the Message Criteria for the detected/selected venue.
  // Tapping any criteria navigates to Screen 2 displaying the suggested messages for that criterion.
  function openCategoryMessagesScreen(catKey) {
    const screenMainHome = document.getElementById('screen-main-home');
    const screenCategoryMessages = document.getElementById('screen-category-messages');
    const messagesGrid = document.getElementById('messages-grid');
    const meta = HOSPITAL_CATEGORY_METADATA[catKey] || BANK_CATEGORY_METADATA[catKey] || {
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

      // Layer group for other facility pins
      venueMarkersGroup = L.layerGroup().addTo(areaMap);

      // Render all Sri Lanka hospitals and banks onto the map immediately
      renderSriLankaHospitals(allHospitalsData);
      renderSriLankaBanks(allBanksData);

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

      const slHospitalsFocusBtn = document.getElementById('map-hospitals-focus-btn');
      if (slHospitalsFocusBtn) {
        slHospitalsFocusBtn.addEventListener('click', () => {
          areaMap.flyTo([6.9197, 79.8693], 14, { animate: true, duration: 1 });
          showGpsToast("🏙️ Focused on Central Colombo Venues (Hospitals & Banks)", 2500);
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

      // Map click handler: clicking near any hospital or bank on the map selects it directly
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

        if (minDHosp <= minDBank && closestHosp && minDHosp < 0.04) {
          selectHospitalFromMap(closestHosp.id, closestHosp.lat, closestHosp.lon, closestHosp.name);
        } else if (closestBank && minDBank < 0.04) {
          selectBankFromMap(closestBank.id, closestBank.lat, closestBank.lon, closestBank.name);
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

  // Render Horizontal Pills Strip on Map (Hospitals in Red, Banks in Blue)
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
  }

  function renderMapHospitalPills(hospitalsList) {
    if (hospitalsList) allHospitalsData = hospitalsList;
    renderMapCombinedPills();
  }

  // Core Function: Select Hospital Directly From Map
  function selectHospitalFromMap(id, lat, lon, name) {
    // 1. Highlight map pin
    document.querySelectorAll('.map-hospital-pin, .map-bank-pin').forEach(p => p.classList.remove('selected-map-pin'));
    const targetPin = document.getElementById(`map-pin-${id}`);
    if (targetPin) {
      targetPin.classList.add('selected-map-pin');
    }

    // 2. Highlight map pill button
    document.querySelectorAll('.map-hospital-pill-btn, .map-bank-pill-btn').forEach(btn => {
      if (btn.getAttribute('data-id') === id) {
        btn.classList.add('active-hospital-pill');
        btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      } else {
        btn.classList.remove('active-hospital-pill', 'active-bank-pill');
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
    document.querySelectorAll('.map-hospital-pin, .map-bank-pin').forEach(p => p.classList.remove('selected-map-pin'));
    const targetPin = document.getElementById(`map-pin-${id}`);
    if (targetPin) {
      targetPin.classList.add('selected-map-pin');
    }

    // 2. Highlight map pill button
    document.querySelectorAll('.map-hospital-pill-btn, .map-bank-pill-btn').forEach(btn => {
      if (btn.getAttribute('data-id') === id) {
        btn.classList.add('active-bank-pill');
        btn.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      } else {
        btn.classList.remove('active-hospital-pill', 'active-bank-pill');
      }
    });

    // 3. Open marker popup
    if (bankMarkersMap[id]) {
      bankMarkersMap[id].openPopup();
    }

    // 4. Trigger selection
    manuallySelectBank(id, lat, lon, name);
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

  function renderVenuePins(facilities) {
    if (!venueMarkersGroup || typeof L === 'undefined') return;
    venueMarkersGroup.clearLayers();
  }

  // Global helper for Leaflet popups and manual buttons to select a hospital or bank
  window.selectHospitalFromMap = selectHospitalFromMap;
  window.selectHospitalManually = selectHospitalFromMap;
  window.triggerSimulateHospital = selectHospitalFromMap;
  window.selectBankFromMap = selectBankFromMap;
  window.selectBankManually = selectBankFromMap;

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

    // 1. Update Hero Card
    if (data.manually_selected) {
      if (locTitle) locTitle.textContent = placeName;
      if (locEyebrow) {
        if (isHospital) locEyebrow.textContent = `HOSPITAL SELECTED FROM MAP • සිතියමෙන් තෝරාගත් රෝහල`;
        else if (isBank) locEyebrow.textContent = `BANK SELECTED FROM MAP • සිතියමෙන් තෝරාගත් බැංකුව`;
        else locEyebrow.textContent = `SELECTED FROM MAP • සිතියමෙන් තෝරාගත් ස්ථානය`;
      }
      if (locSub) locSub.textContent = data.address || (isHospital ? `Selected on map • Hospital communication ready` : (isBank ? `Selected on map • Bank communication ready` : `Selected on map`));
      if (liveBadgeText) liveBadgeText.textContent = isHospital ? `MAP • HOSPITAL` : (isBank ? `MAP • BANK` : `MAP • VENUE`);
    } else if (isPredefined) {
      if (locTitle) locTitle.textContent = placeName;
      if (locEyebrow) {
        if (isHospital) locEyebrow.textContent = `GPS DETECTED HOSPITAL • රෝහල හඳුනා ගන්නා ලදී`;
        else if (isBank) locEyebrow.textContent = `GPS DETECTED BANK • බැංකුව හඳුනා ගන්නා ලදී`;
        else locEyebrow.textContent = `GPS DETECTED VENUE • ${facilityName.toUpperCase()}`;
      }
      if (locSub) locSub.textContent = data.address || `GPS Lock • Accuracy ±${Math.round(accuracy)}m`;
      if (liveBadgeText) liveBadgeText.textContent = isHospital ? `LIVE • HOSPITAL` : (isBank ? `LIVE • BANK` : `LIVE • ${facilityName.toUpperCase()}`);
    } else {
      // User is OUTSIDE predefined facilities
      if (locTitle) locTitle.textContent = areaName;
      if (locEyebrow) locEyebrow.textContent = `GPS AREA LOCATION • OUTSIDE VENUE`;
      if (locSub) locSub.textContent = data.address ? `Near ${data.address} • Venue scanning active` : `GPS Coordinates Lock (±${Math.round(accuracy)}m) • Ready to detect hospital or bank`;
      if (liveBadgeText) liveBadgeText.textContent = `LIVE • SCANNING`;
    }

    if (avatar) {
      if (data.theme_color) avatar.style.color = data.theme_color;
      if (data.bg_color) avatar.style.background = data.bg_color;
    }
    if (badgeIcon && data.badge_icon) {
      badgeIcon.className = `fa-solid ${data.badge_icon}`;
    }

    // 2. Hospital / Bank Detection vs Waiting State Message Delivery
    const waitingCard = document.getElementById('waiting-hospital-state');
    const categorySection = document.getElementById('section-category-criteria');
    const hospitalCategoryBar = document.getElementById('category-selector-bar');
    const bankCategoryBar = document.getElementById('bank-category-selector-bar');
    const hospitalBadge = document.getElementById('hospital-status-badge');
    const sectionHeading = document.getElementById('section-messages-heading');
    const messagesGrid = document.getElementById('messages-grid');

    if (isHospital) {
      if (waitingCard) waitingCard.style.display = 'none';
      if (categorySection) categorySection.style.display = 'block';
      if (hospitalCategoryBar) {
        hospitalCategoryBar.style.display = 'flex';
        hospitalCategoryBar.style.flexDirection = 'column';
      }
      if (bankCategoryBar) bankCategoryBar.style.display = 'none';
      if (hospitalBadge) {
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
        document.querySelectorAll('.map-hospital-pin').forEach(p => p.classList.remove('selected-map-pin'));
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

      // If user is currently on Screen 2, refresh its displayed messages
      const screenCatMessages = document.getElementById('screen-category-messages');
      if (screenCatMessages && screenCatMessages.style.display !== 'none' && currentActiveHospitalCategory) {
        const msgs = (cachedHospitalCategories[currentActiveHospitalCategory] || cachedBankCategories[currentActiveHospitalCategory]) || [];
        renderHospitalMessages(msgs);
        if (messagesGrid) {
          messagesGrid.style.display = 'flex';
          messagesGrid.style.flexDirection = 'column';
        }
        const subCount = document.getElementById('subscreen-count-pill');
        if (subCount) subCount.textContent = msgs.length;
      }

      const hintText = document.getElementById('category-hint-text');
      if (hintText) {
        hintText.style.display = 'block';
        hintText.innerHTML = '<i class="fa-solid fa-hand-pointer"></i> Press a category button above to view suggested messages';
      }
    } else if (isBank) {
      if (waitingCard) waitingCard.style.display = 'none';
      if (categorySection) categorySection.style.display = 'block';
      if (hospitalCategoryBar) hospitalCategoryBar.style.display = 'none';
      if (bankCategoryBar) {
        bankCategoryBar.style.display = 'flex';
        bankCategoryBar.style.flexDirection = 'column';
      }
      if (hospitalBadge) {
        hospitalBadge.style.display = 'inline-flex';
        hospitalBadge.innerHTML = '<i class="fa-solid fa-building-columns"></i> 2 Categories';
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
        document.querySelectorAll('.map-bank-pin').forEach(p => p.classList.remove('selected-map-pin'));
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

      // If user is currently on Screen 2, refresh its displayed messages
      const screenCatMessages = document.getElementById('screen-category-messages');
      if (screenCatMessages && screenCatMessages.style.display !== 'none' && currentActiveHospitalCategory) {
        const msgs = (cachedBankCategories[currentActiveHospitalCategory] || cachedHospitalCategories[currentActiveHospitalCategory]) || [];
        renderHospitalMessages(msgs);
        if (messagesGrid) {
          messagesGrid.style.display = 'flex';
          messagesGrid.style.flexDirection = 'column';
        }
        const subCount = document.getElementById('subscreen-count-pill');
        if (subCount) subCount.textContent = msgs.length;
      }

      const hintText = document.getElementById('category-hint-text');
      if (hintText) {
        hintText.style.display = 'block';
        hintText.innerHTML = '<i class="fa-solid fa-hand-pointer"></i> Press a category button above to view suggested messages';
      }
    } else {
      // User is NOT in hospital or bank: hide categories, show waiting card
      if (waitingCard) {
        waitingCard.style.display = 'block';
        const waitingDesc = waitingCard.querySelector('.waiting-desc');
        if (waitingDesc) {
          waitingDesc.innerHTML = `Currently at <strong>${placeName || areaName}</strong>. Select a hospital (🔴) or bank (🔵) on the map, or wait for GPS to detect your venue.`;
        }
      }
      if (categorySection) categorySection.style.display = 'none';
      if (hospitalCategoryBar) hospitalCategoryBar.style.display = 'none';
      if (bankCategoryBar) bankCategoryBar.style.display = 'none';
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
        mapStatusText.textContent = `Current Area (${areaName}). Tap red pin for hospital or blue pin for bank.`;
      }
      if (mapLiveStatusTag) {
        mapLiveStatusTag.textContent = `Select Hospital / Bank on Map`;
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
    if (data.manually_selected && data.is_bank) {
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
      showGpsToast(`📍 Area: ${areaName}. Tap red pin for hospital or blue pin for bank.`, 3000);
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

            // Fetch Sri Lanka hospitals & banks sorted by distance from current GPS position
            fetchNearbySriLankaHospitals(lat, lon);
            fetchNearbySriLankaBanks(lat, lon);
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

  function simulateHospitalCoordinates(lat, lon, name) {
    return manuallySelectHospital(null, lat, lon, name);
  }

  function simulateBankCoordinates(lat, lon, name) {
    return manuallySelectBank(null, lat, lon, name);
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

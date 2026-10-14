import 'package:flutter/material.dart';
import '../models/communication_models.dart';

class CommunicationData {
  // -------------------------------------------------------------
  // SUPERMARKET (9 Categories, 100 Messages)
  // -------------------------------------------------------------
  static const List<CommunicationCategory> supermarketCategories = [
    CommunicationCategory(
      id: 'sm-basic-comm',
      key: 'sm-basic-comm',
      name: '1. මූලික සන්නිවේදනය / Basic communication',
      nameSi: 'මූලික සන්නිවේදනය',
      nameEn: 'Basic communication',
      icon: Icons.chat_outlined,
      count: 10,
      messages: [
        CommunicationMessage(id: 1, templateEn: 'I am deaf.', templateSi: 'මම බිහිරි කෙනෙක්.', category: 'Basic communication'),
        CommunicationMessage(id: 2, templateEn: 'I cannot speak.', templateSi: 'මට කතා කරන්න බැහැ.', category: 'Basic communication'),
        CommunicationMessage(id: 3, templateEn: 'Please write down your message.', templateSi: 'කරුණාකර ඔබේ පණිවිඩය ලියන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 4, templateEn: 'Please speak slowly and face me.', templateSi: 'කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 5, templateEn: 'Please wait a moment.', templateSi: 'කරුණාකර මොහොතක් රැඳී සිටින්න.', category: 'Basic communication'),
        CommunicationMessage(id: 6, templateEn: 'Please repeat that.', templateSi: 'කරුණාකර නැවත කියන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 7, templateEn: 'I do not understand.', templateSi: 'මට තේරෙන්නේ නැහැ.', category: 'Basic communication'),
        CommunicationMessage(id: 8, templateEn: 'Yes.', templateSi: 'ඔව්.', category: 'Basic communication'),
        CommunicationMessage(id: 9, templateEn: 'No.', templateSi: 'නැහැ.', category: 'Basic communication'),
        CommunicationMessage(id: 10, templateEn: 'Thank you.', templateSi: 'ස්තූතියි.', category: 'Basic communication'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-help-facilities',
      key: 'sm-help-facilities',
      name: '2. ආධාර සහ පහසුකම් ලබා ගැනීම / Getting help and facilities',
      nameSi: 'ආධාර සහ පහසුකම් ලබා ගැනීම',
      nameEn: 'Getting help and facilities',
      icon: Icons.help_outline,
      count: 10,
      messages: [
        CommunicationMessage(id: 11, templateEn: 'I need help.', templateSi: 'මට උදව්වක් අවශ්යයි.', category: 'Getting help and facilities'),
        CommunicationMessage(id: 12, templateEn: 'Can you help me find something?', templateSi: 'මට යමක් සොයාගැනීමට උදව් කරන්න පුළුවන් ද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 13, templateEn: 'Where is the customer service desk?', templateSi: 'ගනුදෙනුකරු සේවා මේසය කොහෙද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 14, templateEn: 'May I speak to the manager?', templateSi: 'මට කළමනාකරු හමුවීමට පුළුවන් ද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 15, templateEn: 'Where is the toilet?', templateSi: 'වැසිකිළිය කොහෙද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 16, templateEn: 'Where is the entrance?', templateSi: 'ඇතුල්වීමේ දොර කොහෙද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 17, templateEn: 'Where is the exit?', templateSi: 'පිටවීමේ දොර කොහෙද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 18, templateEn: 'Where can I get a trolley?', templateSi: 'ට්රොලිය ලබාගන්නේ කොහෙන්ද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 19, templateEn: 'Where can I get a shopping basket?', templateSi: 'සාප්පු කූඩයක් ලබාගන්නේ කොහෙන්ද?', category: 'Getting help and facilities'),
        CommunicationMessage(id: 20, templateEn: 'Can you show me the way?', templateSi: 'මට පාර පෙන්වන්න පුළුවන් ද?', category: 'Getting help and facilities'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-finding-products',
      key: 'sm-finding-products',
      name: '3. නිෂ්පාදන සොයා ගැනීම / Finding products',
      nameSi: 'නිෂ්පාදන සොයා ගැනීම',
      nameEn: 'Finding products',
      icon: Icons.inventory_2_outlined,
      count: 26,
      messages: [
        CommunicationMessage(id: 21, templateEn: 'Where is the rice?', templateSi: 'සහල් කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 22, templateEn: 'Where is the milk?', templateSi: 'කිරි කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 23, templateEn: 'Where is the bread?', templateSi: 'පාන් කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 24, templateEn: 'Where is the vegetable section?', templateSi: 'එළවළු අංශය කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 25, templateEn: 'Where is the fruit section?', templateSi: 'පළතුරු අංශය කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 26, templateEn: 'Where is the meat section?', templateSi: 'මස් අංශය කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 27, templateEn: 'Where is the fish section?', templateSi: 'මාළු අංශය කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 28, templateEn: 'Where is the dairy section?', templateSi: 'කිරි නිෂ්පාදන අංශය කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 29, templateEn: 'Where is the bakery section?', templateSi: 'බේකරි අංශය කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 30, templateEn: 'Where are the spices?', templateSi: 'කුළුබඩු කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 31, templateEn: 'Where is the cooking oil?', templateSi: 'පිසින තෙල් කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 32, templateEn: 'Where are the eggs?', templateSi: 'බිත්තර කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 33, templateEn: 'Where is the sugar?', templateSi: 'සීනි කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 34, templateEn: 'Where is the salt?', templateSi: 'ලුණු කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 35, templateEn: 'Where is the tea?', templateSi: 'තේ කොළ කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 36, templateEn: 'Where is the flour?', templateSi: 'පිටි කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 37, templateEn: 'Where are the lentils?', templateSi: 'පරිප්පු කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 38, templateEn: 'Where are the snacks?', templateSi: 'කෙටි ආහාර (ස්නැක්ස්) කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 39, templateEn: 'Where are the beverages?', templateSi: 'බීම වර්ග කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 40, templateEn: 'Where are the frozen foods?', templateSi: 'ශීත කළ ආහාර කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 41, templateEn: 'Where are the cleaning products?', templateSi: 'පිරිසිදු කිරීමේ නිෂ්පාදන කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 42, templateEn: 'Where are the personal care items?', templateSi: 'පුද්ගලික සුව පහසු භාණ්ඩ කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 43, templateEn: 'Where are the baby products?', templateSi: 'ළදරු භාණ්ඩ කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 44, templateEn: 'Where are the household items?', templateSi: 'ගෘහ භාණ්ඩ කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 45, templateEn: 'Where are the batteries?', templateSi: 'බැටරි කොහෙද?', category: 'Finding products'),
        CommunicationMessage(id: 46, templateEn: 'Do you have this item? (showing a picture)', templateSi: 'ඔබ ළඟ මෙම භාණ්ඩය තියෙනවා ද?', category: 'Finding products'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-prices-offers',
      key: 'sm-prices-offers',
      name: '4. මිල ගණන් සහ දීමනා / Prices and offers',
      nameSi: 'මිල ගණන් සහ දීමනා',
      nameEn: 'Prices and offers',
      icon: Icons.local_offer_outlined,
      count: 10,
      messages: [
        CommunicationMessage(id: 47, templateEn: 'How much is this?', templateSi: 'මෙය කීයද?', category: 'Prices and offers'),
        CommunicationMessage(id: 48, templateEn: 'There is no price tag on this.', templateSi: 'මෙයට මිල ලේබලයක් නැහැ.', category: 'Prices and offers'),
        CommunicationMessage(id: 49, templateEn: 'Can you check the price for me?', templateSi: 'මට මිල පරීක්ෂා කර දෙන්න පුළුවන් ද?', category: 'Prices and offers'),
        CommunicationMessage(id: 50, templateEn: 'Please write down the price.', templateSi: 'කරුණාකර මිල ලියන්න.', category: 'Prices and offers'),
        CommunicationMessage(id: 51, templateEn: 'Is this on sale?', templateSi: 'මෙය අඩු මිලට තියෙනවා ද?', category: 'Prices and offers'),
        CommunicationMessage(id: 52, templateEn: 'Are there any discounts today?', templateSi: 'අද වට්ටම් තියෙනවා ද?', category: 'Prices and offers'),
        CommunicationMessage(id: 53, templateEn: 'I have a membership card.', templateSi: 'මා ළඟ සාමාජික කාඩ්පතක් තියෙනවා.', category: 'Prices and offers'),
        CommunicationMessage(id: 54, templateEn: 'I have a discount coupon.', templateSi: 'මා ළඟ වට්ටම් කූපනයක් තියෙනවා.', category: 'Prices and offers'),
        CommunicationMessage(id: 55, templateEn: 'Do you have a cheaper option?', templateSi: 'මීට වඩා ලාභ විකල්පයක් තියෙනවා ද?', category: 'Prices and offers'),
        CommunicationMessage(id: 56, templateEn: 'The price on the shelf is different.', templateSi: 'රාක්කයේ මිල වෙනස්.', category: 'Prices and offers'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-product-info-dietary',
      key: 'sm-product-info-dietary',
      name: '5. නිෂ්පාදන තොරතුරු සහ ආහාරමය අවශ්යතා / Product info & dietary',
      nameSi: 'නිෂ්පාදන තොරතුරු සහ ආහාරමය අවශ්යතා',
      nameEn: 'Product information and dietary needs',
      icon: Icons.info_outline,
      count: 12,
      messages: [
        CommunicationMessage(id: 57, templateEn: 'What is the expiry date?', templateSi: 'කල් ඉකුත් වන දිනය කුමක්ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 58, templateEn: 'Please check the expiry date for me.', templateSi: 'කරුණාකර කල් ඉකුත් වන දිනය බලා දෙන්න.', category: 'Product info & dietary'),
        CommunicationMessage(id: 59, templateEn: 'Is there a fresher one?', templateSi: 'මීට වඩා නැවුම් එකක් තියෙනවා ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 60, templateEn: 'Does this contain nuts? I am allergic.', templateSi: 'මෙහි පරිප්පු අඩංගු ද? මට අසාත්මිකතාවක් තියෙනවා.', category: 'Product info & dietary'),
        CommunicationMessage(id: 61, templateEn: 'Please check the ingredients for me.', templateSi: 'කරුණාකර අමුද්රව්ය බලා දෙන්න.', category: 'Product info & dietary'),
        CommunicationMessage(id: 62, templateEn: 'I am diabetic. Do you have sugar-free products?', templateSi: 'මම දියවැඩියා රෝගියෙක්. සීනි රහිත නිෂ්පාදන තියෙනවා ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 63, templateEn: 'Do you have low-salt products?', templateSi: 'ලුණු අඩු නිෂ්පාදන තියෙනවා ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 64, templateEn: 'Is this suitable for vegetarians?', templateSi: 'මෙය නිර්මාංශිකයන්ට සුදුසු ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 65, templateEn: 'Is this halal?', templateSi: 'මෙය හලාල් ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 66, templateEn: 'Do you have gluten-free products?', templateSi: 'ග්ලූටන් රහිත නිෂ්පාදන තියෙනවා ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 67, templateEn: 'Do you have a larger size?', templateSi: 'විශාල ප්රමාණයක් තියෙනවා ද?', category: 'Product info & dietary'),
        CommunicationMessage(id: 68, templateEn: 'Do you have a smaller size?', templateSi: 'කුඩා ප්රමාණයක් තියෙනවා ද?', category: 'Product info & dietary'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-weighing-packing',
      key: 'sm-weighing-packing',
      name: '6. බර කිරා බැලීම, කැපීම සහ ඇසුරුම් කිරීම / Weighing & packing',
      nameSi: 'බර කිරා බැලීම, කැපීම සහ ඇසුරුම් කිරීම',
      nameEn: 'Weighing, cutting and packing',
      icon: Icons.scale_outlined,
      count: 8,
      messages: [
        CommunicationMessage(id: 69, templateEn: 'Please weigh this for me.', templateSi: 'කරුණාකර මෙය කිරලා දෙන්න.', category: 'Weighing and packing'),
        CommunicationMessage(id: 70, templateEn: 'I would like 250 grams.', templateSi: 'මට ග්රෑම් 250ක් අවශ්යයි.', category: 'Weighing and packing'),
        CommunicationMessage(id: 71, templateEn: 'I would like half a kilogram.', templateSi: 'මට කිලෝ භාගයක් අවශ්යයි.', category: 'Weighing and packing'),
        CommunicationMessage(id: 72, templateEn: 'I would like one kilogram.', templateSi: 'මට කිලෝවක් අවශ්යයි.', category: 'Weighing and packing'),
        CommunicationMessage(id: 73, templateEn: 'Please cut it into small pieces.', templateSi: 'කරුණාකර කුඩා කෑලි වලට කපන්න.', category: 'Weighing and packing'),
        CommunicationMessage(id: 74, templateEn: 'Please clean the fish.', templateSi: 'කරුණාකර මාළු පිරිසිදු කරන්න.', category: 'Weighing and packing'),
        CommunicationMessage(id: 75, templateEn: 'Please give me fresh ones.', templateSi: 'කරුණාකර නැවුම් ඒවා දෙන්න.', category: 'Weighing and packing'),
        CommunicationMessage(id: 76, templateEn: 'Please pack it separately.', templateSi: 'කරුණාකර වෙන වෙනම ඇසුරුම් කරන්න.', category: 'Weighing and packing'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-checkout-payment',
      key: 'sm-checkout-payment',
      name: '7. පිරික්සුම සහ ගෙවීම / Checkout and payment',
      nameSi: 'පිරික්සුම සහ ගෙවීම',
      nameEn: 'Checkout and payment',
      icon: Icons.point_of_sale_outlined,
      count: 14,
      messages: [
        CommunicationMessage(id: 77, templateEn: 'Which counter is open?', templateSi: 'කුමන කවුන්ටරය විවෘතද?', category: 'Checkout and payment'),
        CommunicationMessage(id: 78, templateEn: 'Is this the queue for payment?', templateSi: 'ගෙවීම සඳහා පෝලිම මෙයද?', category: 'Checkout and payment'),
        CommunicationMessage(id: 79, templateEn: 'I have only a few items. May I go first?', templateSi: 'මා ළඟ ඇත්තේ භාණ්ඩ කිහිපයයි. මට කලින් යන්න පුළුවන් ද?', category: 'Checkout and payment'),
        CommunicationMessage(id: 80, templateEn: 'Please show me the total amount.', templateSi: 'කරුණාකර මුළු මුදල මට පෙන්වන්න.', category: 'Checkout and payment'),
        CommunicationMessage(id: 81, templateEn: 'Please write down the total amount.', templateSi: 'කරුණාකර මුළු මුදල ලියන්න.', category: 'Checkout and payment'),
        CommunicationMessage(id: 82, templateEn: 'Can I pay by card?', templateSi: 'කාඩ්පතෙන් ගෙවන්න පුළුවන් ද?', category: 'Checkout and payment'),
        CommunicationMessage(id: 83, templateEn: 'I will pay in cash.', templateSi: 'මම මුදලින් ගෙවන්නම්.', category: 'Checkout and payment'),
        CommunicationMessage(id: 84, templateEn: 'Can I pay using a QR code?', templateSi: 'QR කේතයෙන් ගෙවන්න පුළුවන් ද?', category: 'Checkout and payment'),
        CommunicationMessage(id: 85, templateEn: 'Please give me a receipt.', templateSi: 'කරුණාකර රිසිට්පතක් දෙන්න.', category: 'Checkout and payment'),
        CommunicationMessage(id: 86, templateEn: 'May I have a bag, please?', templateSi: 'කරුණාකර මට බෑගයක් දෙන්න.', category: 'Checkout and payment'),
        CommunicationMessage(id: 87, templateEn: 'I have my own bag.', templateSi: 'මා ළඟ මගේම බෑගයක් තියෙනවා.', category: 'Checkout and payment'),
        CommunicationMessage(id: 88, templateEn: 'Please pack the items in separate bags.', templateSi: 'කරුණාකර භාණ්ඩ වෙනම බෑග් වල දාන්න.', category: 'Checkout and payment'),
        CommunicationMessage(id: 89, templateEn: 'Can you help me carry my shopping?', templateSi: 'මගේ බඩු රැගෙන යාමට උදව් කරන්න පුළුවන් ද?', category: 'Checkout and payment'),
        CommunicationMessage(id: 90, templateEn: 'I think the change is incorrect. Please check.', templateSi: 'ඉතිරි මුදල වැරදියි කියා මට හිතෙනවා. කරුණාකර පරීක්ෂා කරන්න.', category: 'Checkout and payment'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-problems-returns',
      key: 'sm-problems-returns',
      name: '8. නිෂ්පාදන ආපසු යැවීම / Problems and returns',
      nameSi: 'නිෂ්පාදන ආපසු යැවීම',
      nameEn: 'Problems and returns',
      icon: Icons.replay_outlined,
      count: 6,
      messages: [
        CommunicationMessage(id: 91, templateEn: 'I think I was charged twice.', templateSi: 'මට දෙවරක් අය කළා කියා හිතෙනවා.', category: 'Problems and returns'),
        CommunicationMessage(id: 92, templateEn: 'I want to return this item.', templateSi: 'මට මෙම භාණ්ඩය ආපසු දීමට අවශ්යයි.', category: 'Problems and returns'),
        CommunicationMessage(id: 93, templateEn: 'I want to exchange this item.', templateSi: 'මට මෙම භාණ්ඩය මාරු කරගැනීමට අවශ්යයි.', category: 'Problems and returns'),
        CommunicationMessage(id: 94, templateEn: 'This item is damaged.', templateSi: 'මෙම භාණ්ඩය හානි වී තියෙනවා.', category: 'Problems and returns'),
        CommunicationMessage(id: 95, templateEn: 'This item is expired.', templateSi: 'මෙම භාණ්ඩය කල් ඉකුත් වී තියෙනවා.', category: 'Problems and returns'),
        CommunicationMessage(id: 96, templateEn: 'I want a refund.', templateSi: 'මට මුදල් ආපසු ලබාගැනීමට අවශ්යයි.', category: 'Problems and returns'),
      ],
    ),
    CommunicationCategory(
      id: 'sm-closing-courtesy',
      key: 'sm-closing-courtesy',
      name: '9. සමාප්තිය සහ ආචාරශීලීත්වය / Closing and courtesy',
      nameSi: 'සමාප්තිය සහ ආචාරශීලීත්වය',
      nameEn: 'Closing and courtesy',
      icon: Icons.handshake_outlined,
      count: 4,
      messages: [
        CommunicationMessage(id: 97, templateEn: 'Please tap my shoulder or wave to get my attention.', templateSi: 'කරුණාකර මගේ අවධානය ලබාගැනීමට උරහිසට තට්ටු කරන්න හෝ අත වනන්න.', category: 'Closing and courtesy'),
        CommunicationMessage(id: 98, templateEn: 'Do you offer home delivery?', templateSi: 'ඔබ ගෙදරටම බෙදාහරින්නේ ද?', category: 'Closing and courtesy'),
        CommunicationMessage(id: 99, templateEn: 'What time do you close?', templateSi: 'ඔබ වසන්නේ කීයටද?', category: 'Closing and courtesy'),
        CommunicationMessage(id: 100, templateEn: 'Thank you for your help.', templateSi: 'ඔබේ උදව්වට ස්තූතියි.', category: 'Closing and courtesy'),
      ],
    ),
  ];

  // -------------------------------------------------------------
  // HOSPITAL (Clinical Communication)
  // -------------------------------------------------------------
  static const List<CommunicationCategory> hospitalCategories = [
    CommunicationCategory(
      id: 'hosp-emergency',
      key: 'hosp-emergency',
      name: '1. හදිසි අවස්ථා / Emergency & Urgent Help',
      nameSi: 'හදිසි අවස්ථා',
      nameEn: 'Emergency & Urgent Help',
      icon: Icons.emergency_outlined,
      count: 5,
      messages: [
        CommunicationMessage(id: 1, templateEn: 'I am deaf. I cannot speak.', templateSi: 'මම බිහිරි කෙනෙක්. මට කතා කරන්න බැහැ.', category: 'Emergency'),
        CommunicationMessage(id: 2, templateEn: 'I need urgent medical attention.', templateSi: 'මට හදිසි වෛද්‍ය ප්‍රතිකාර අවශ්‍යයි.', category: 'Emergency'),
        CommunicationMessage(id: 3, templateEn: 'I am having severe chest pain.', templateSi: 'මට දැඩි පපුවේ වේදනාවක් තිබෙනවා.', category: 'Emergency'),
        CommunicationMessage(id: 4, templateEn: 'I have difficulty breathing.', templateSi: 'මට හුස්ම ගැනීමේ අපහසුවක් ඇත.', category: 'Emergency'),
        CommunicationMessage(id: 5, templateEn: 'Please call a doctor quickly.', templateSi: 'කරුණාකර ඉක්මනින් වෛද්‍යවරයකු අමතන්න.', category: 'Emergency'),
      ],
    ),
    CommunicationCategory(
      id: 'hosp-registration',
      key: 'hosp-registration',
      name: '2. ලියාපදිංචිය සහ ඇතුළත් වීම / Registration & Admission',
      nameSi: 'ලියාපදිංචිය සහ ඇතුළත් වීම',
      nameEn: 'Registration & Admission',
      icon: Icons.how_to_reg_outlined,
      count: 4,
      messages: [
        CommunicationMessage(id: 6, templateEn: 'Where is the OPD registration desk?', templateSi: 'OPD ලියාපදිංචි කවුන්ටරය කොහේද?', category: 'Registration'),
        CommunicationMessage(id: 7, templateEn: 'I have an appointment with the doctor.', templateSi: 'මට වෛද්‍යවරයා හමුවීමට වේලාවක් වෙන් කර ඇත.', category: 'Registration'),
        CommunicationMessage(id: 8, templateEn: 'Here is my National Identity Card and hospital book.', templateSi: 'මෙන්න මගේ හැඳුනුම්පත සහ සායන පොත.', category: 'Registration'),
        CommunicationMessage(id: 9, templateEn: 'Please write down my token or clinic number.', templateSi: 'කරුණාකර මගේ ටෝකන් හෝ සායන අංකය ලියා දෙන්න.', category: 'Registration'),
      ],
    ),
    CommunicationCategory(
      id: 'hosp-symptoms',
      key: 'hosp-symptoms',
      name: '3. රෝග ලක්ෂණ විස්තර කිරීම / Describing Symptoms',
      nameSi: 'රෝග ලක්ෂණ විස්තර කිරීම',
      nameEn: 'Describing Symptoms',
      icon: Icons.sick_outlined,
      count: 5,
      messages: [
        CommunicationMessage(id: 10, templateEn: 'I have a high fever and chills.', templateSi: 'මට අධික උණ සහ වෙව්ලීම තිබෙනවා.', category: 'Symptoms'),
        CommunicationMessage(id: 11, templateEn: 'I have had this pain for 3 days.', templateSi: 'මට දින 3 ක් තිස්සේ මෙම වේදනාව පවතී.', category: 'Symptoms'),
        CommunicationMessage(id: 12, templateEn: 'I feel dizzy and nauseous.', templateSi: 'මට කරකැවිල්ල සහ වමනය ඇති වේ.', category: 'Symptoms'),
        CommunicationMessage(id: 13, templateEn: 'I have diabetes and high blood pressure.', templateSi: 'මට දියවැඩියාව සහ අධික රුධිර පීඩනය තිබේ.', category: 'Symptoms'),
        CommunicationMessage(id: 14, templateEn: 'I am allergic to penicillin and certain antibiotics.', templateSi: 'මට පෙනිසිලින් සහ සමහර ඖෂධ වලට අසාත්මිකතාවක් තිබේ.', category: 'Symptoms'),
      ],
    ),
    CommunicationCategory(
      id: 'hosp-pharmacy',
      key: 'hosp-pharmacy',
      name: '4. ඖෂධ ලබා ගැනීම / Pharmacy & Medication',
      nameSi: 'ඖෂධ ලබා ගැනීම',
      nameEn: 'Pharmacy & Medication',
      icon: Icons.medication_outlined,
      count: 4,
      messages: [
        CommunicationMessage(id: 15, templateEn: 'Where is the hospital pharmacy?', templateSi: 'රෝහල් ඖෂධාගාරය කොහේද?', category: 'Pharmacy'),
        CommunicationMessage(id: 16, templateEn: 'Here is my prescription.', templateSi: 'මෙන්න මගේ බෙහෙත් වට්ටෝරුව.', category: 'Pharmacy'),
        CommunicationMessage(id: 17, templateEn: 'Please write down how to take these medicines.', templateSi: 'කරුණාකර මෙම ඖෂධ ගත යුතු ආකාරය ලියා දෙන්න.', category: 'Pharmacy'),
        CommunicationMessage(id: 18, templateEn: 'Should I take this medicine before or after meals?', templateSi: 'මෙම ඖෂධ ආහාරයට පෙරද නැතහොත් පසුවද ගත යුත්තේ?', category: 'Pharmacy'),
      ],
    ),
  ];

  // -------------------------------------------------------------
  // BANK (Banking & Financial Services)
  // -------------------------------------------------------------
  static const List<CommunicationCategory> bankCategories = [
    CommunicationCategory(
      id: 'bank-basic-comm',
      key: 'bank-basic-comm',
      name: '1. මූලික සන්නිවේදනය / Basic communication',
      nameSi: 'මූලික සන්නිවේදනය',
      nameEn: 'Basic communication',
      icon: Icons.chat_outlined,
      count: 10,
      messages: [
        CommunicationMessage(id: 1, templateEn: 'I am deaf. I cannot speak.', templateSi: 'මම බිහිරි කෙනෙක්. මට කතා කරන්න බැහැ.', category: 'Basic communication'),
        CommunicationMessage(id: 2, templateEn: 'Please write down the instructions on paper.', templateSi: 'කරුණාකර උපදෙස් කොළයක ලියා දෙන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 3, templateEn: 'Where is the customer service officer?', templateSi: 'පාරිභෝගික සේවා නිලධාරියා කොහේද?', category: 'Basic communication'),
        CommunicationMessage(id: 4, templateEn: 'Please speak slowly and face me.', templateSi: 'කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 5, templateEn: 'Thank you for your assistance.', templateSi: 'ඔබේ උපකාරයට ස්තූතියි.', category: 'Basic communication'),
      ],
    ),
    CommunicationCategory(
      id: 'bank-deposits',
      key: 'bank-deposits',
      name: '2. තැන්පතු සහ මුදල් ලබා ගැනීම / Deposits & Withdrawals',
      nameSi: 'තැන්පතු සහ මුදල් ලබා ගැනීම',
      nameEn: 'Deposits & Withdrawals',
      icon: Icons.savings_outlined,
      count: 6,
      messages: [
        CommunicationMessage(id: 6, templateEn: 'I want to deposit money into my savings account.', templateSi: 'මට මගේ ඉතුරුම් ගිණුමට මුදල් තැන්පත් කිරීමට අවශ්‍යයි.', category: 'Deposits'),
        CommunicationMessage(id: 7, templateEn: 'I want to withdraw money from my account.', templateSi: 'මට මගේ ගිණුමෙන් මුදල් ලබා ගැනීමට අවශ්‍යයි.', category: 'Withdrawals'),
        CommunicationMessage(id: 8, templateEn: 'Please update my passbook.', templateSi: 'කරුණාකර මගේ බැංකු පොත යාවත්කාලීන කරන්න.', category: 'Services'),
        CommunicationMessage(id: 9, templateEn: 'What is my current account balance?', templateSi: 'මගේ ගිණුමේ ශේෂය කීයද?', category: 'Inquiries'),
        CommunicationMessage(id: 10, templateEn: 'Here is my deposit slip and cash.', templateSi: 'මෙන්න තැන්පතු පත්‍රිකාව සහ මුදල්.', category: 'Deposits'),
      ],
    ),
    CommunicationCategory(
      id: 'bank-cards',
      key: 'bank-cards',
      name: '3. කාඩ්පත් සහ ATM / Cards & ATM Services',
      nameSi: 'කාඩ්පත් සහ ATM',
      nameEn: 'Cards & ATM Services',
      icon: Icons.credit_card_outlined,
      count: 5,
      messages: [
        CommunicationMessage(id: 11, templateEn: 'I want to apply for a debit card.', templateSi: 'මට ඩෙබිට් කාඩ්පතක් සඳහා ඉල්ලුම් කිරීමට අවශ්‍යයි.', category: 'Cards'),
        CommunicationMessage(id: 12, templateEn: 'My ATM card was captured / swallowed by the machine.', templateSi: 'මගේ ATM කාඩ්පත යන්ත්‍රයට හිරවුණා.', category: 'ATM'),
        CommunicationMessage(id: 13, templateEn: 'Please block my lost ATM card immediately.', templateSi: 'කරුණාකර මගේ නැතිවූ ATM කාඩ්පත අවහිර කරන්න.', category: 'Security'),
        CommunicationMessage(id: 14, templateEn: 'How can I activate mobile banking?', templateSi: 'මොබයිල් බෑන්කින් සක්‍රිය කරන්නේ කෙසේද?', category: 'Digital'),
      ],
    ),
  ];

  // -------------------------------------------------------------
  // RESTAURANT (Dining & Food Ordering)
  // -------------------------------------------------------------
  static const List<CommunicationCategory> restaurantCategories = [
    CommunicationCategory(
      id: 'rest-basic-comm',
      key: 'rest-basic-comm',
      name: '1. මූලික සන්නිවේදනය / Basic communication',
      nameSi: 'මූලික සන්නිවේදනය',
      nameEn: 'Basic communication',
      icon: Icons.chat_outlined,
      count: 10,
      messages: [
        CommunicationMessage(id: 1, templateEn: 'I am deaf. I cannot speak.', templateSi: 'මම බිහිරි කෙනෙක්. මට කතා කරන්න බැහැ.', category: 'Basic communication'),
        CommunicationMessage(id: 2, templateEn: 'Please point on the menu or write down.', templateSi: 'කරුණාකර මෙනුවේ පෙන්වන්න හෝ ලියන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 3, templateEn: 'Please give me a few minutes to decide.', templateSi: 'තීරණය කිරීමට මට මිනිත්තු කිහිපයක් දෙන්න.', category: 'Basic communication'),
        CommunicationMessage(id: 4, templateEn: 'Thank you very much.', templateSi: 'බොහොම ස්තූතියි.', category: 'Basic communication'),
      ],
    ),
    CommunicationCategory(
      id: 'rest-seating',
      key: 'rest-seating',
      name: '2. පැමිණීම සහ අසුන් ගැනීම / Arrival & Seating',
      nameSi: 'පැමිණීම සහ අසුන් ගැනීම',
      nameEn: 'Arrival and seating',
      icon: Icons.chair_outlined,
      count: 6,
      messages: [
        CommunicationMessage(id: 5, templateEn: 'A table for one, please.', templateSi: 'කරුණාකර එක් අයෙකුට මේසයක් දෙන්න.', category: 'Seating'),
        CommunicationMessage(id: 6, templateEn: 'A table for two, please.', templateSi: 'කරුණාකර දෙදෙනෙකුට මේසයක් දෙන්න.', category: 'Seating'),
        CommunicationMessage(id: 7, templateEn: 'May we sit by the window?', templateSi: 'අපට ජනේලය අසල වාඩි විය හැකිද?', category: 'Seating'),
        CommunicationMessage(id: 8, templateEn: 'Is this table reserved?', templateSi: 'මෙම මේසය වෙන් කර තිබේද?', category: 'Seating'),
      ],
    ),
    CommunicationCategory(
      id: 'rest-menu-ordering',
      key: 'rest-menu-ordering',
      name: '3. මෙනුව සහ ඇණවුම් කිරීම / Menu & Ordering',
      nameSi: 'මෙනුව සහ ඇණවුම් කිරීම',
      nameEn: 'Menu and ordering',
      icon: Icons.restaurant_menu_outlined,
      count: 8,
      messages: [
        CommunicationMessage(id: 9, templateEn: 'May I see the food menu, please?', templateSi: 'කරුණාකර කෑම මෙනුව බලන්න පුළුවන් ද?', category: 'Menu'),
        CommunicationMessage(id: 10, templateEn: 'What do you recommend as today special?', templateSi: 'අද විශේෂ කෑම ලෙස ඔබ නිර්දේශ කරන්නේ කුමක්ද?', category: 'Ordering'),
        CommunicationMessage(id: 11, templateEn: 'I would like to order chicken fried rice.', templateSi: 'මට චිකන් ෆ්‍රයිඩ් රයිස් එකක් ඇණවුම් කිරීමට අවශ්‍යයි.', category: 'Ordering'),
        CommunicationMessage(id: 12, templateEn: 'Please make it non-spicy / less spicy.', templateSi: 'කරුණාකර සැර අඩුවෙන් සාදා දෙන්න.', category: 'Customization'),
        CommunicationMessage(id: 13, templateEn: 'Please bring the bill / check.', templateSi: 'කරුණාකර බිල ගෙනැවිත් දෙන්න.', category: 'Bill & Payment'),
      ],
    ),
  ];

  static List<CommunicationCategory> getCategoriesForVenue(VenueType type) {
    switch (type) {
      case VenueType.supermarket:
        return supermarketCategories;
      case VenueType.hospital:
        return hospitalCategories;
      case VenueType.bank:
        return bankCategories;
      case VenueType.restaurant:
        return restaurantCategories;
      case VenueType.other:
        return supermarketCategories;
    }
  }
}

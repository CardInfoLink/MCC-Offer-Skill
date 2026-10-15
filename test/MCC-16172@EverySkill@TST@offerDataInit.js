// @ts-nocheck
// ============================================================
// MCC-16172 权益推荐 Offer Skill - EverySkill 联调测试数据脚本
// 执行库：offercent（应用 EverySkill，节点 TST）
// 说明：本文件为 MongoDB Shell 脚本，仅用于测试数据初始化，不修改正式数据。
//
// 数据范围：
//   1. every_tags：补充本脚本依赖的测试标签；
//   2. every_offer：写入 4 条测试 Offer；
//   3. every_offer_tags：写入 Offer 与标签的相关度关系。
//   4. 不创建或迁移索引，索引由 EverySkill 后端启动代码负责。
//
// 幂等规则：
//   - 标签按 tag_name 判断；
//   - Offer 按 source + source_offer_id 判断；
//   - OfferTag 按 offer_id + tag_id 判断；
//   - 已存在记录不覆盖，便于重复执行。
// ============================================================

print("########## MCC-16172 Offer 测试数据初始化开始 ##########");

var NOW = ISODate("2026-10-12T00:00:00.000+0800");
var OFFER_SOURCE = "MCC-16172-TEST";
var AI_MODEL_VERSION = "MCC-16172-TEST-1.0";

// ============================================================
// 01 测试标签：供 OfferTag 关系和本地查询联调使用
// ============================================================
print("\n=== [01_tags] 开始写入测试标签 ===");

var tags = [
  {
    name: "温泉度假",
    desc: "以温泉为主题的休闲度假活动",
    level: "L3",
    weight: 0.85,
  },
  {
    name: "亲子",
    desc: "适合家庭亲子出行的活动场所",
    level: "L2",
    weight: 0.45,
  },
  {
    name: "酒店",
    desc: "酒店住宿相关的权益",
    level: "L2",
    weight: 0.45,
  },
  {
    name: "机场贵宾厅",
    desc: "机场贵宾厅休息室使用权益",
    level: "L3",
    weight: 0.85,
  },
];

var tagIds = {};
tags.forEach(function (t) {
  var old = db.getCollection("every_tags").findOne({ tag_name: t.name });
  if (old) {
    tagIds[t.name] = old._id;
    print("  [跳过] 标签已存在: " + t.name + " -> " + old._id);
    return;
  }

  var result = db.getCollection("every_tags").insertOne({
    tag_name: t.name,
    tag_description: t.desc,
    generalization_level: t.level,
    tag_weight: t.weight,
    is_active: true,
    created_at: NOW,
    updated_at: NOW,
  });
  tagIds[t.name] = result.insertedId;
  print("  [插入] 标签: " + t.name + " -> " + result.insertedId);
});

// ============================================================
// 02 SKILL 配置发布快照：基于本脚本测试数据生成 every_skill_config
// 配置内容分别对应 config/regions.txt、config/banks.txt、config/tags.txt。
// 本节只生成/插入配置快照，不创建或迁移索引；索引由 EverySkill 后端负责。
// ============================================================
print("\n=== [02_skill_config] 开始写入测试配置快照 ===");

var CONFIG_VERSION = "2026-10-12-MCC-16172-TEST";
var regionsContent = "香港 台湾 新加坡";
var banksContent = [
  "ABC：中国农业银行、农业银行、ABC、农行",
  "ICBC：中国工商银行、工商银行、ICBC、工行",
].join("\n");
var tagsContent = tags
  .map(function (t) {
    return t.name + "：" + t.desc;
  })
  .join("\n");

(function () {
  var configColl = db.getCollection("every_skill_config");
  var existed = configColl.findOne({ version: CONFIG_VERSION });
  if (existed) {
    print("  [跳过] 配置版本已存在: " + CONFIG_VERSION);
    return;
  }

  var contents = [regionsContent, banksContent, tagsContent];
  for (var i = 0; i < contents.length; i++) {
    if (contents[i].indexOf("=.==.=") !== -1) {
      print("  [错误] 配置内容含响应分隔符 =.==.=，中止写入");
      return;
    }
  }

  var disabled = 0;
  for (var n = 0; n < 50; n++) {
    var oldEnabled = configColl.findOne({ status: "enabled" });
    if (!oldEnabled) break;
    configColl.updateOne(
      { _id: oldEnabled._id },
      { $set: { status: "disabled", updated_at: NOW } }
    );
    print("  [停用] 旧配置版本: " + oldEnabled.version);
    disabled++;
  }

  configColl.insertOne({
    version: CONFIG_VERSION,
    status: "enabled",
    regions_content: regionsContent,
    banks_content: banksContent,
    tags_content: tagsContent,
    created_at: NOW,
    updated_at: NOW,
  });
  print("  [插入] 配置版本: " + CONFIG_VERSION + "，停用旧版本 " + disabled + " 条");
})();

// ============================================================
// 03 测试 Offer：覆盖地区、银行、默认推荐和多标签场景
// ============================================================
print("\n=== [03_offers] 开始写入测试 Offer ===");

var offers = [
  {
    source_offer_id: "OFFER-TEST-HOTSPRING-HK",
    title: "香港温泉酒店万事达专享礼遇",
    description: "使用万事达信用卡预订香港温泉酒店，可享住宿折扣及亲子温泉体验。",
    merchant_name: "香港山泉度假酒店",
    offer_summary: "香港温泉酒店住宿与亲子体验优惠。",
    benefit_type: "discount",
    activation_type: "USER_ACTIVATION",
    categories: ["酒店", "温泉度假", "亲子"],
    use_mode: "online",
    banks: ["ABC"],
    regions: ["香港"],
    start_time: ISODate("2026-10-01T00:00:00.000+0800"),
    end_time: ISODate("2026-12-31T23:59:59.000+0800"),
    eligibility_requirement: "使用 ABC 万事达信用卡支付，具体以活动细则为准。",
    offer_url: "https://example.com/mcc-16172/offer/hotspring-hk",
    logo: "",
    default_recommend: true,
  },
  {
    source_offer_id: "OFFER-TEST-FAMILY-HK",
    title: "香港亲子乐园家庭优惠",
    description: "万事达信用卡用户购买香港亲子乐园门票，可享家庭套票优惠。",
    offer_summary: "香港亲子乐园家庭套票优惠。",
    benefit_type: "voucher",
    activation_type: "USER_ACTIVATION",
    categories: ["亲子", "娱乐"],
    use_mode: "online",
    banks: ["ABC", "ICBC"],
    regions: ["香港"],
    start_time: ISODate("2026-10-01T00:00:00.000+0800"),
    end_time: ISODate("2026-11-30T23:59:59.000+0800"),
    eligibility_requirement: "限指定万事达信用卡用户，每卡限购数量以活动细则为准。",
    offer_url: "https://example.com/mcc-16172/offer/family-hk",
    logo: "",
    default_recommend: false,
  },
  {
    source_offer_id: "OFFER-TEST-AIRPORT-TW",
    title: "台湾机场贵宾厅体验礼遇",
    description: "符合条件的万事达信用卡持卡人可预约台湾机场贵宾厅服务。",
    offer_summary: "台湾机场贵宾厅服务礼遇。",
    benefit_type: "service",
    activation_type: "USER_ACTIVATION",
    categories: ["机场", "旅行"],
    use_mode: "both",
    banks: ["ICBC"],
    regions: ["台湾"],
    start_time: ISODate("2026-10-01T00:00:00.000+0800"),
    end_time: ISODate("2026-12-31T23:59:59.000+0800"),
    eligibility_requirement: "需使用 ICBC 万事达信用卡并提前预约。",
    offer_url: "https://example.com/mcc-16172/offer/airport-tw",
    logo: "",
    default_recommend: true,
  },
  {
    source_offer_id: "OFFER-TEST-GENERAL-APAC",
    title: "亚洲精选酒店通用礼遇",
    description: "万事达信用卡用户在指定亚洲酒店消费，可享专属价格或服务礼遇。",
    offer_summary: "面向多个亚洲地区的酒店通用礼遇。",
    benefit_type: "discount",
    activation_type: "AUTO_ACTIVATION",
    categories: ["酒店", "旅行"],
    use_mode: "online",
    banks: ["ABC", "ICBC"],
    regions: ["香港", "台湾", "新加坡"],
    start_time: ISODate("2026-10-01T00:00:00.000+0800"),
    end_time: ISODate("2027-03-31T23:59:59.000+0800"),
    eligibility_requirement: "适用于指定酒店及指定万事达信用卡，具体以活动细则为准。",
    offer_url: "https://example.com/mcc-16172/offer/general-apac",
    logo: "",
    default_recommend: false,
  },
];

// 内部关系统一使用 MongoDB 自动生成的 every_offer._id。
var offerObjectIds = {};
offers.forEach(function (o) {
  var filter = { source: OFFER_SOURCE, source_offer_id: o.source_offer_id };
  var old = db.getCollection("every_offer").findOne(filter);
  if (old) {
    offerObjectIds[o.source_offer_id] = old._id;
    print("  [跳过] Offer 已存在: " + o.source_offer_id + " -> " + old._id);
    return;
  }

  var doc = {
    source: OFFER_SOURCE,
    source_offer_id: o.source_offer_id,
    title: o.title,
    description: o.description,
    merchant_name: o.merchant_name,
    offer_summary: o.offer_summary,
    benefit_type: o.benefit_type,
    activation_type: o.activation_type,
    categories: o.categories,
    use_mode: o.use_mode,
    banks: o.banks,
    regions: o.regions,
    start_time: o.start_time,
    end_time: o.end_time,
    eligibility_requirement: o.eligibility_requirement,
    offer_url: o.offer_url,
    logo: o.logo,
    default_recommend: o.default_recommend,
    source_created_at: NOW,
    source_updated_at: NOW,
    created_at: NOW,
    updated_at: NOW,
    is_deleted: false,
  };
  var result = db.getCollection("every_offer").insertOne(doc);
  offerObjectIds[o.source_offer_id] = result.insertedId;
  print("  [插入] Offer: " + o.source_offer_id + " -> " + result.insertedId);
});

// ============================================================
// 04 OfferTag 关系：相关度用于标签召回和命中打分
// ============================================================
// OfferTag 关系中的 offer_id 是 every_offer._id，source_offer_id 仅用于来源侧幂等查找。
print("\n=== [04_offer_tags] 开始写入 OfferTag 关系 ===");

var offerTags = [
  { offer: "OFFER-TEST-HOTSPRING-HK", tag: "温泉度假", score: 96 },
  { offer: "OFFER-TEST-HOTSPRING-HK", tag: "酒店", score: 90 },
  { offer: "OFFER-TEST-HOTSPRING-HK", tag: "亲子", score: 72 },
  { offer: "OFFER-TEST-FAMILY-HK", tag: "亲子", score: 96 },
  { offer: "OFFER-TEST-FAMILY-HK", tag: "酒店", score: 55 },
  { offer: "OFFER-TEST-AIRPORT-TW", tag: "机场贵宾厅", score: 98 },
  { offer: "OFFER-TEST-GENERAL-APAC", tag: "酒店", score: 86 },
  { offer: "OFFER-TEST-GENERAL-APAC", tag: "温泉度假", score: 40 },
  { offer: "OFFER-TEST-GENERAL-APAC", tag: "机场贵宾厅", score: 35 },
  { offer: "OFFER-TEST-GENERAL-APAC", tag: "亲子", score: 30 },
];

var relationInserted = 0;
var relationSkipped = 0;
offerTags.forEach(function (r) {
  var offerObjectId = offerObjectIds[r.offer];
  var tagId = tagIds[r.tag];
  if (!offerObjectId || !tagId) {
    print("  [错误] 找不到关联对象: " + r.offer + " / " + r.tag);
    return;
  }

  var filter = { offer_id: offerObjectId, tag_id: tagId };
  if (db.getCollection("every_offer_tags").findOne(filter)) {
    print("  [跳过] OfferTag 已存在: " + r.offer + " / " + r.tag);
    relationSkipped++;
    return;
  }

  db.getCollection("every_offer_tags").insertOne({
    offer_id: offerObjectId,
    tag_id: tagId,
    relevance_score: r.score,
    is_manual: false,
    ai_model_version: AI_MODEL_VERSION,
    created_at: NOW,
    updated_at: NOW,
  });
  print("  [插入] OfferTag: " + r.offer + " / " + r.tag + " = " + r.score);
  relationInserted++;
});

// ============================================================
// 05 只读核对：确认测试数据和关系均可回查
// ============================================================
print("\n=== [05_verify] 开始核对 ===");

var offerCount = 0;
offers.forEach(function (o) {
  if (db.getCollection("every_offer").findOne({ source: OFFER_SOURCE, source_offer_id: o.source_offer_id })) {
    offerCount++;
  }
});

var relationCount = 0;
offerTags.forEach(function (r) {
  var offerObjectId = offerObjectIds[r.offer];
  var tagId = tagIds[r.tag];
  if (offerObjectId && tagId && db.getCollection("every_offer_tags").findOne({ offer_id: offerObjectId, tag_id: tagId })) {
    relationCount++;
  }
});

print("  Offer: " + offerCount + "/" + offers.length + " 条存在");
print("  OfferTag: " + relationCount + "/" + offerTags.length + " 条存在");
print("  本次新增 OfferTag: " + relationInserted + " 条，已存在: " + relationSkipped + " 条");
print("=== [04_verify] 完成 ===");
print("\n########## MCC-16172 Offer 测试数据初始化结束 ##########");

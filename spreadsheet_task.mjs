import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const inputPath = "C:/Users/lenovo/Desktop/时间性能仿真汇总.xlsx";
const csvPath = "outputs/time_performance_simulation/time_performance_results.csv";
const outputPath = "outputs/time_performance_simulation/时间性能仿真汇总_补全.xlsx";
const previewDir = "outputs/time_performance_simulation/preview_after";

// 导入用户原始工作簿，保留已有的双层表头、合并单元格和版式。
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);
const sheet = workbook.worksheets.getItem("Sheet1");

// 使用 artifact-tool 读取 MATLAB 批量仿真生成的 CSV，不手工解析 CSV 文本。
const csvText = await fs.readFile(csvPath, "utf8");
const csvWorkbook = await Workbook.fromCSV(csvText, { sheetName: "Results" });
const csvSheet = csvWorkbook.worksheets.getItem("Results");
const csvValues = csvSheet.getUsedRange().values;
const data = csvValues.slice(1).map((row) => row.map((value) => Number(value)));

if (data.length !== 68 || data.some((row) => row.length !== 14 || row.some((v) => !Number.isFinite(v)))) {
  throw new Error("仿真结果应包含 68 行、14 列有限数值。请检查 MATLAB 输出。");
}

// 清除模板中的旧结果，只替换数据区；第 1、2 行表头保持不变。
sheet.getRange("A3:N200").clear({ applyTo: "contents" });
sheet.getRange("A3:N70").values = data;

// 延续原表的简洁网格样式，并突出两个寻峰方法之间的分区边界。
const body = sheet.getRange("A3:N70");
body.format.font = { name: "等线", size: 11, color: "#000000" };
body.format.horizontalAlignment = "right";
body.format.verticalAlignment = "center";
body.format.rowHeight = 20;
body.format.borders = { preset: "all", style: "thin", color: "#D9D9D9" };

sheet.getRange("A3:D70").format.numberFormat = "0";
sheet.getRange("E3:F70").format.numberFormat = "0.000";
sheet.getRange("G3:G70").format.numberFormat = "0.000000";
sheet.getRange("H3:I70").format.numberFormat = "0.000000";
sheet.getRange("J3:K70").format.numberFormat = "0.000";
sheet.getRange("L3:L70").format.numberFormat = "0.000000";
sheet.getRange("M3:N70").format.numberFormat = "0.000000";

for (const column of ["A", "D", "I", "N"]) {
  sheet.getRange(`${column}1:${column}70`).format.borders = {
    right: { style: "medium", color: "#808080" },
  };
}

// 固定双层表头，便于浏览 68 行结果；列宽按标题长度设置以避免截断。
sheet.freezePanes.freezeRows(2);
const widths = {
  A: 12, B: 15, C: 12, D: 14,
  E: 18, F: 13, G: 16, H: 12, I: 12,
  J: 18, K: 13, L: 16, M: 12, N: 12,
};
for (const [column, width] of Object.entries(widths)) {
  sheet.getRange(`${column}:${column}`).format.columnWidth = width;
}
sheet.getRange("A1:N2").format.wrapText = true;
sheet.getRange("A1:N2").format.verticalAlignment = "center";
sheet.getRange("1:2").format.rowHeight = 30;

// 导出补全后的 Excel 文件。
await fs.mkdir(previewDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

// 关键范围和公式错误扫描，作为交付前的程序化 QA。
const region = await workbook.inspect({
  kind: "region",
  sheetId: sheet.name,
  range: "A1:N70",
  maxChars: 10000,
  tableMaxRows: 8,
  tableMaxCols: 14,
});
process.stdout.write(`${region.ndjson}\n`);

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
process.stdout.write(`${errors.ndjson}\n`);

// 渲染完整工作表，供视觉检查布局、截断和样式一致性。
const preview = await workbook.render({
  sheetName: sheet.name,
  range: "A1:N70",
  scale: 1.25,
  format: "png",
});
await fs.writeFile(`${previewDir}/Sheet1.png`, new Uint8Array(await preview.arrayBuffer()));
process.stdout.write(`Saved: ${outputPath}\nRows: ${data.length}\n`);

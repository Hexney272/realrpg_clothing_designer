using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using CodeWalker.GameFiles;

namespace RealRpgClothingBridge
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            try
            {
                if (args.Length == 0 || args[0] == "--help" || args[0] == "help")
                {
                    PrintJson(true, "help", "Usage: extract|inject --ytd file.ytd --texture name --out file --work folder --texconv texconv.exe [--png image.png]");
                    return 0;
                }

                var command = args[0].ToLowerInvariant();
                var opt = Args.Parse(args.Skip(1).ToArray());
                var work = FullPath(opt.Get("work", Path.Combine(Path.GetTempPath(), "realrpg_clothing_bridge")));
                Directory.CreateDirectory(work);

                if (command == "extract")
                {
                    Extract(opt, work);
                    return 0;
                }
                if (command == "inject")
                {
                    Inject(opt, work);
                    return 0;
                }

                throw new Exception("Unknown command: " + command);
            }
            catch (Exception ex)
            {
                PrintJson(false, ex.Message, null, ex.ToString());
                return 1;
            }
        }

        private static void Extract(Args opt, string work)
        {
            var ytdPath = Required(opt, "ytd");
            var textureName = opt.Get("texture", "");
            var outPath = FullPath(Required(opt, "out"));
            var texconv = Required(opt, "texconv");
            Directory.CreateDirectory(Path.GetDirectoryName(outPath));

            var dump = PrepareDump(ytdPath, work);
            var dds = FindTextureDds(dump.DdsFolder, textureName);
            Run(texconv, "-y", "-ft", "png", "-o", Path.GetDirectoryName(outPath), dds);

            var produced = Path.Combine(Path.GetDirectoryName(outPath), Path.GetFileNameWithoutExtension(dds) + ".png");
            if (!File.Exists(produced)) throw new Exception("texconv did not create PNG: " + produced);
            if (!SamePath(produced, outPath))
            {
                if (File.Exists(outPath)) File.Delete(outPath);
                File.Move(produced, outPath);
            }

            PrintJson(true, null, null, null, new JsonPair("pngPath", outPath), new JsonPair("textureName", Path.GetFileNameWithoutExtension(dds)), new JsonPair("ytdPath", ytdPath));
        }

        private static void Inject(Args opt, string work)
        {
            var ytdPath = FullPath(Required(opt, "ytd"));
            var pngPath = FullPath(Required(opt, "png"));
            var textureName = opt.Get("texture", "");
            var outPath = FullPath(Required(opt, "out"));
            var texconv = Required(opt, "texconv");
            Directory.CreateDirectory(Path.GetDirectoryName(outPath));

            var dump = PrepareDump(ytdPath, work);
            var targetDds = FindTextureDds(dump.DdsFolder, textureName);
            var targetBase = Path.GetFileNameWithoutExtension(targetDds);
            var stagedPng = Path.Combine(dump.DdsFolder, targetBase + ".png");
            if (File.Exists(stagedPng)) File.Delete(stagedPng);
            File.Copy(pngPath, stagedPng);

            Run(texconv, "-y", "-f", "BC3_UNORM", "-m", "0", "-if", "CUBIC", "-o", dump.DdsFolder, stagedPng);
            var convertedDds = Path.Combine(dump.DdsFolder, targetBase + ".dds");
            if (!File.Exists(convertedDds)) throw new Exception("texconv did not create replacement DDS: " + convertedDds);

            var ytd = XmlYtd.GetYtd(dump.Xml, dump.DdsFolder);
            var bytes = ytd.Save();
            File.WriteAllBytes(outPath, bytes);
            PrintJson(true, null, null, null, new JsonPair("outputPath", outPath), new JsonPair("textureName", targetBase), new JsonPair("sourceYtd", ytdPath));
        }

        private static DumpResult PrepareDump(string ytdPath, string work)
        {
            ytdPath = FullPath(ytdPath);
            if (!File.Exists(ytdPath)) throw new FileNotFoundException("YTD file not found", ytdPath);
            var dumpFolder = Path.Combine(work, "dump_" + DateTime.UtcNow.Ticks.ToString("x"));
            Directory.CreateDirectory(dumpFolder);

            var ytd = new YtdFile();
            ytd.Load(File.ReadAllBytes(ytdPath));
            ytd.Name = Path.GetFileName(ytdPath);
            var xml = YtdXml.GetXml(ytd, dumpFolder);
            File.WriteAllText(Path.Combine(dumpFolder, "texture_dictionary.xml"), xml, Encoding.UTF8);

            if (!Directory.GetFiles(dumpFolder, "*.dds", SearchOption.TopDirectoryOnly).Any())
            {
                throw new Exception("CodeWalker did not export any DDS from this YTD. Check that the file is a valid GTA V .ytd.");
            }
            return new DumpResult { DdsFolder = dumpFolder, Xml = xml };
        }

        private static string FindTextureDds(string folder, string textureName)
        {
            var files = Directory.GetFiles(folder, "*.dds", SearchOption.TopDirectoryOnly);
            if (files.Length == 0) throw new Exception("No DDS files were exported.");
            var wanted = (textureName ?? "").Trim().ToLowerInvariant().Replace(".dds", "");
            if (!string.IsNullOrWhiteSpace(wanted))
            {
                var exact = files.FirstOrDefault(f => Path.GetFileNameWithoutExtension(f).ToLowerInvariant() == wanted);
                if (exact != null) return exact;
                var contains = files.FirstOrDefault(f => Path.GetFileNameWithoutExtension(f).ToLowerInvariant().Contains(wanted));
                if (contains != null) return contains;
            }
            return files.FirstOrDefault(f => Path.GetFileNameWithoutExtension(f).ToLowerInvariant().Contains("diff")) ?? files[0];
        }

        private static void Run(string exe, params string[] args)
        {
            exe = FullPath(exe);
            if (!File.Exists(exe)) throw new FileNotFoundException("Tool not found", exe);
            var psi = new ProcessStartInfo
            {
                FileName = exe,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            };
            foreach (var a in args) psi.ArgumentList.Add(a);
            using (var p = Process.Start(psi))
            {
                var stdout = p.StandardOutput.ReadToEnd();
                var stderr = p.StandardError.ReadToEnd();
                p.WaitForExit();
                if (p.ExitCode != 0) throw new Exception($"{Path.GetFileName(exe)} failed ({p.ExitCode}): {stderr}\n{stdout}");
            }
        }

        private static string Required(Args opt, string name)
        {
            var v = opt.Get(name, null);
            if (string.IsNullOrWhiteSpace(v)) throw new Exception("Missing --" + name);
            return FullPath(v);
        }

        private static string FullPath(string p) => Path.GetFullPath(Environment.ExpandEnvironmentVariables(p ?? ""));
        private static bool SamePath(string a, string b) => string.Equals(FullPath(a).TrimEnd('\\', '/'), FullPath(b).TrimEnd('\\', '/'), StringComparison.OrdinalIgnoreCase);

        private static void PrintJson(bool ok, string error = null, string message = null, string detail = null, params JsonPair[] pairs)
        {
            var sb = new StringBuilder();
            sb.Append("{\"ok\":").Append(ok ? "true" : "false");
            if (error != null) sb.Append(",\"error\":\"").Append(Escape(error)).Append("\"");
            if (message != null) sb.Append(",\"message\":\"").Append(Escape(message)).Append("\"");
            if (detail != null) sb.Append(",\"detail\":\"").Append(Escape(detail)).Append("\"");
            foreach (var p in pairs) sb.Append(",\"").Append(Escape(p.Name)).Append("\":\"").Append(Escape(p.Value)).Append("\"");
            sb.Append("}");
            Console.WriteLine(sb.ToString());
        }

        private static string Escape(string s) => (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n");

        private sealed class DumpResult { public string DdsFolder; public string Xml; }
        private readonly struct JsonPair { public readonly string Name; public readonly string Value; public JsonPair(string n, string v) { Name = n; Value = v; } }

        private sealed class Args
        {
            private readonly System.Collections.Generic.Dictionary<string, string> _values = new System.Collections.Generic.Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            public static Args Parse(string[] args)
            {
                var a = new Args();
                for (int i = 0; i < args.Length; i++)
                {
                    if (!args[i].StartsWith("--")) continue;
                    var key = args[i].Substring(2);
                    var val = (i + 1 < args.Length && !args[i + 1].StartsWith("--")) ? args[++i] : "true";
                    a._values[key] = val;
                }
                return a;
            }
            public string Get(string name, string fallback) => _values.TryGetValue(name, out var v) ? v : fallback;
        }
    }
}

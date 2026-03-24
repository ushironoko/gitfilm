///|
pub(all) struct FileContent {
  lines : Array[String]
} derive(Eq, Show)

///|
pub(all) struct DiffSummary {
  added : Int
  removed : Int
} derive(Eq, Show)

///|
pub(all) struct Commit {
  id : String
  files : Map[String, FileContent]
  parent : String?
} derive(Show)

///|
pub(all) struct WorkingTree {
  files : Map[String, FileContent]
} derive(Show)

///|
pub(all) struct StagingArea {
  files : Map[String, FileContent]
} derive(Show)

///|
pub(all) struct Repository {
  commits : Array[Commit]
  head : Int
} derive(Show)

///|
pub(all) struct GitState {
  working_tree : WorkingTree
  staging_area : StagingArea
  repository : Repository
  next_commit_seq : Int
} derive(Show)

///|
pub(all) enum Operation {
  Add(String)
  Commit
  ResetSoft(Int)
  ResetMixed(Int)
  ResetHard(Int)
  Restore(String)
  Checkout(String)
  Rm(String)
} derive(Show)

///|
pub(all) enum FileStatus {
  Untracked
  Modified(DiffSummary)
  Staged(DiffSummary)
  Committed(String)
  Deleted
  Clean
} derive(Show)

///|
pub fn FileContent::empty() -> FileContent {
  { lines: [] }
}

///|
pub fn FileContent::from_string(s : String) -> FileContent {
  { lines: s.split("\n").map(fn(sv) { sv.to_string() }).collect() }
}

///|
pub fn FileContent::is_empty(self : FileContent) -> Bool {
  self.lines.is_empty()
}

///|
pub fn diff_summary(old : FileContent, new_ : FileContent) -> DiffSummary {
  let mut added = 0
  let mut removed = 0
  for line in old.lines {
    if not(new_.lines.contains(line)) {
      removed = removed + 1
    }
  }
  for line in new_.lines {
    if not(old.lines.contains(line)) {
      added = added + 1
    }
  }
  { added, removed }
}

///|
pub fn generate_commit_id(seq : Int) -> String {
  let s = seq.to_string()
  let padding = "0".repeat(6 - s.length())
  "c" + padding + s
}

///|
pub fn Repository::head_commit(self : Repository) -> Commit? {
  if self.head >= 0 && self.head < self.commits.length() {
    Some(self.commits[self.head])
  } else {
    None
  }
}

///|
pub fn Repository::get_file_at_head(self : Repository, path : String) -> FileContent {
  match self.head_commit() {
    Some(commit) => commit.files.get(path).unwrap_or(FileContent::empty())
    None => FileContent::empty()
  }
}

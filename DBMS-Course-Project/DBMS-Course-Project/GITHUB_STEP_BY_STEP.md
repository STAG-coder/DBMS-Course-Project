# GitHub Submission Guide

## 1. Create the repository
1. Go to https://github.com/
2. Sign in.
3. Click **New repository**.
4. Repository name: `DBMS-Course-Project`
5. Select **Public**.
6. Add a README only if you prefer; this package already contains one.
7. Create the repository.

## 2. Put the project files in the required folders
The repository must look like:

DBMS-Course-Project/
├── README.md
├── Presentation-I/
├── Presentation-II/
├── Presentation-III/
└── Project-Report/

## 3. Before uploading
Edit:
- `README.md` → enter your roll number and faculty name.
- `Presentation-II/query_solution_Presentation-II.md` → enter the exact query given during Presentation-II and its real output.
- `Project-Report/Smart_Parking_DBMS_Project_Report.pdf` → if you change the placeholders, regenerate/update the PDF.
- Replace the screenshot placeholders in `Presentation-III/Screenshots/` with actual screenshots from your running UI.

## 4. Easiest upload method — GitHub website
1. Open your repository.
2. Click **Add file → Upload files**.
3. Drag the contents of this project folder into the upload area.
4. Scroll to **Commit changes**.
5. Use a meaningful message, for example:
   `Initial DBMS project submission`
6. Click **Commit changes**.

## 5. Make regular commits
Your instructions say the commit history will be checked. Do NOT upload everything in one final commit if you can avoid it.

Recommended history:
- `Initial repository structure`
- `Added Presentation I problem description`
- `Added Presentation II database schema and ER diagram`
- `Added final SQL and sample data`
- `Added Presentation III UI`
- `Added UI screenshots`
- `Added final project report`
- `Final submission cleanup`

If you use Git locally:

```bash
git init
git branch -M main
git remote add origin https://github.com/YOUR-USERNAME/DBMS-Course-Project.git

git add README.md
git commit -m "Initial repository structure"
git push -u origin main

git add Presentation-I
git commit -m "Added Presentation I"
git push

git add Presentation-II
git commit -m "Added Presentation II database design"
git push

git add Presentation-III
git commit -m "Added Presentation III UI"
git push

git add Project-Report
git commit -m "Added final project report"
git push
```

## 6. Verify the repository
Open the public repository URL in an incognito/private browser window and check:
- README is visible.
- All four required folders exist.
- PPT/PDF files open.
- SQL file is present.
- ER diagram is present.
- UI source code is present.
- Actual screenshots are present.
- Final PDF report is present.

## 7. Submit the repository link
Use:
`https://github.com/YOUR-USERNAME/DBMS-Course-Project`

Do not submit a local file path.

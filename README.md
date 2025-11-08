>  **Blockchain-powered verification for AI-generated financial and business reports**

## 📋 Overview

This Clarity smart contract provides an immutable audit trail for AI-generated reports, ensuring document integrity and preventing post-generation tampering. Perfect for financial institutions, auditors, and regulatory compliance.

## ✨ Key Features

- 🔒 **Immutable Timestamping** - Reports are hashed and timestamped on-chain immediately after AI generation
- 👥 **Role-Based Access** - Designated auditors can verify and challenge reports
- 📚 **Version History** - Complete audit trail of all report modifications
- 🛡️ **Tamper Proof** - Cryptographic hashes ensure document integrity
- 🏛️ **Regulatory Ready** - Built-in proof-of-generation for compliance
- 💬 **Auditor Feedback** - Detailed textual feedback from auditors for enhanced transparency
- 💬 **Community Comments** - Users can add comments to reports for collaborative feedback and discussions
- 🚩 **Report Flagging** - Community-driven moderation system to highlight potentially problematic reports
- 👍 **Community Endorsement** - Reports can be endorsed by community members, with automatic verification upon reaching endorsement threshold

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for transactions

### Deployment
```bash
clarinet deploy
```

## 💼 Core Functions

### 📝 Submit New Report
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail submit-report 
  hash 
  "GPT-4-Turbo" 
  "Financial-Analysis" 
  "Q4 2024 Revenue Report")
```

### 🔍 Verify Report Integrity
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail verify-report-hash 
  report-id 
  original-hash)
```

### 👨‍💼 Auditor Functions
```clarity
;; Verify a report (auditors only)
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail verify-report report-id)

;; Challenge a report (auditors only)
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail challenge-report 
  report-id 
  "Inconsistent data sources")
```

### 📊 Query Functions
```clarity
;; Get complete report details
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-report report-id)

;; Get audit trail
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-report-trail report-id)

;; Check creator statistics
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-creator-stats creator-principal)
```

## 💬 Auditor Feedback System

### Submit Auditor Feedback
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail submit-auditor-feedback
  report-id
  "Detailed feedback on the report quality and issues found"
  "verify")
```

### Get Auditor Feedback
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-auditor-feedback
  report-id
  auditor-principal)
```

## 💬 Report Commenting System

### Add Comment to Report
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail add-comment
  report-id
  "Your detailed comment about the report")
```

### Get Comment
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-comment
  report-id
  comment-id)
```

### Get Comment Count
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-comment-count
  report-id)
```

## 🚩 Report Flagging System

### Flag a Report
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail flag-report
  report-id)
```

### Get Flag Count
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-flag-count
  report-id)
```

### Check if Report is Flagged
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail is-report-flagged
  report-id)
### Check if Report is Flagged
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail is-report-flagged
  report-id)
```

## 👍 Community Endorsement System

### Endorse a Report
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail endorse-report
  report-id)
```

### Get Endorsement Count
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail get-endorsement-count
  report-id)
```

### Auto-Verification Threshold
Reports automatically become verified when they receive 10 endorsements from community members, streamlining the verification process for highly regarded reports.

## ️ Admin Functions
```

## �️ Admin Functions

### Authorize Auditor
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail authorize-auditor auditor-principal)
```

### Revoke Auditor Access
```clarity
(contract-call? .AI-Generated-Reports-with-Immutable-Audit-Trail revoke-auditor auditor-principal)
```

## 📖 Usage Workflow

1. **🔄 AI Report Generation** - Your AI system generates a financial/business report
2. **🔐 Hash & Submit** - Immediately hash the document and submit to blockchain
3. **📝 Record Metadata** - Store AI model info, report type, and metadata
4. **👨‍💼 Auditor Review** - Authorized auditors can verify or challenge reports
5. **📊 Compliance** - Use audit trail for regulatory reporting

## 🔧 Integration Example

```javascript
// Example: Integrating with your AI reporting system
async function submitAIReport(reportContent, aiModel, reportType) {
  // Generate hash of report content
  const hash = crypto.createHash('sha256').update(reportContent).digest();
  
  // Submit to blockchain
  const result = await clarityContract.submitReport(
    hash,
    aiModel,
    reportType,
    `Generated: ${new Date().toISOString()}`
  );
  
  return result;
}
```

## 📈 Data Structures

### Report Structure
- **Hash**: SHA-256 hash of original document
- **Timestamp**: Block height when submitted
- **Creator**: Principal who submitted the report
- **AI Model**: Which AI system generated the report
- **Report Type**: Category (Financial, Compliance, etc.)
- **Metadata**: Additional context
- **Verified**: Auditor verification status
- **Auditor**: Principal who verified/challenged

### Version Tracking
- **Previous Hash**: Links to prior version
- **Change Reason**: Why the report was updated
- **Timestamp**: When modification occurred

## 🔒 Security Features

- ✅ Only creators can update their reports
- ✅ Only authorized auditors can verify/challenge
- ✅ Immutable version history
- ✅ Cryptographic integrity verification
- ✅ Role-based access control

## 🎯 Use Cases

- 💰 **Financial Reporting** - Quarterly earnings, risk assessments
- 📋 **Compliance Reports** - Regulatory submissions, audit documentation
- 📊 **Business Intelligence** - Market analysis, performance metrics
- 🏦 **Banking** - Credit assessments, loan documentation
- 🏢 **Corporate Governance** - Board reports, stakeholder communications

## 🔍 Error Codes

- `u401` - Unauthorized access
- `u404` - Report not found
- `u409` - Resource already exists
- `u400` - Invalid hash provided

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Add tests for new functionality
4. Submit pull request

## 📄 License

MIT License - See LICENSE file for details

---

🔐 **Built for trust, designed for compliance, powered by blockchain**

# DynamoDB Query Workflow

This document explains how the chatbot uses DynamoDB to query and analyze data through a sophisticated two-step AI workflow.

## Overview

The chatbot now features an intelligent DynamoDB query system that allows users to ask natural language questions about their data. The system:

1. **Generates** a DynamoDB query from the user's question
2. **Executes** the query against your DynamoDB tables
3. **Analyzes** the results and provides a clear answer

## Architecture

```
User Question
     ↓
[LLM: Query Generation]
     ↓
DynamoDB Query (JSON)
     ↓
[DynamoDB Execution]
     ↓
Query Results (JSON)
     ↓
[LLM: Analysis]
     ↓
User-Friendly Answer
```

## Configuration Files

### 1. system_prompt.txt

Contains the system prompt that guides the LLM's behavior. This prompt:
- Defines the assistant's role as a data query specialist
- Provides instructions for query generation
- Sets guidelines for data analysis
- Includes example workflows

**Location:** `backend/system_prompt.txt`

### 2. schema.json

Defines your DynamoDB database structure. This file must be configured with your actual database schema before deployment.

**Location:** `backend/schema.json`

**Required Structure:**
```json
{
  "description": "Your database description",
  "tables": [
    {
      "table_name": "YourTableName",
      "description": "What this table contains",
      "primary_key": {
        "partition_key": {
          "name": "pk",
          "type": "S",
          "description": "Primary key description"
        },
        "sort_key": {
          "name": "sk",
          "type": "S",
          "description": "Sort key description (optional)"
        }
      },
      "attributes": [
        {
          "name": "attribute_name",
          "type": "S|N|BOOL|L|M",
          "description": "Attribute description"
        }
      ],
      "global_secondary_indexes": [
        {
          "index_name": "GSI-Name",
          "partition_key": "gsi_pk",
          "sort_key": "gsi_sk",
          "description": "What this GSI is for"
        }
      ]
    }
  ]
}
```

## Setup Instructions

### 1. Configure Your Schema

Edit `backend/schema.json` with your actual DynamoDB table structure:

```bash
cd backend
nano schema.json  # or use your preferred editor
```

**Example Schema:**
```json
{
  "description": "E-commerce order database",
  "tables": [
    {
      "table_name": "Orders",
      "description": "Customer orders and transactions",
      "primary_key": {
        "partition_key": {
          "name": "customer_id",
          "type": "S",
          "description": "Unique customer identifier"
        },
        "sort_key": {
          "name": "order_date",
          "type": "S",
          "description": "ISO 8601 order timestamp"
        }
      },
      "attributes": [
        {
          "name": "order_id",
          "type": "S",
          "description": "Unique order identifier"
        },
        {
          "name": "total_amount",
          "type": "N",
          "description": "Order total in dollars"
        },
        {
          "name": "status",
          "type": "S",
          "description": "Order status: pending|shipped|delivered|cancelled"
        },
        {
          "name": "items",
          "type": "L",
          "description": "List of order items"
        }
      ],
      "global_secondary_indexes": [
        {
          "index_name": "StatusIndex",
          "partition_key": "status",
          "sort_key": "order_date",
          "description": "Query orders by status and date"
        }
      ]
    }
  ]
}
```

### 2. Customize System Prompt (Optional)

If needed, modify `backend/system_prompt.txt` to:
- Add domain-specific instructions
- Include business rules
- Provide additional context
- Add examples relevant to your data

### 3. Deploy

Deploy the updated backend:

```bash
./deploy.sh --skip-frontend
```

## IAM Permissions

The ECS task role automatically includes permissions for:

- **DynamoDB Operations:**
  - `dynamodb:Query`
  - `dynamodb:Scan`
  - `dynamodb:GetItem`
  - `dynamodb:BatchGetItem`
  - `dynamodb:DescribeTable`

- **Bedrock Operations:**
  - `bedrock:InvokeModel`
  - `bedrock:InvokeModelWithResponseStream`

**Note:** Current permissions allow access to all DynamoDB tables (`Resource: "*"`). For production, consider restricting to specific table ARNs.

## Usage Examples

### Example 1: Simple Query

**User:** "Show me all orders for customer ID 12345"

**System Process:**
1. Generates query:
```json
{
  "operation": "Query",
  "table_name": "Orders",
  "key_condition_expression": "customer_id = :cid",
  "expression_attribute_values": {
    ":cid": {"S": "12345"}
  }
}
```

2. Executes query
3. Returns: "I found 3 orders for customer 12345..."

### Example 2: Filtered Query

**User:** "How many pending orders do we have?"

**System Process:**
1. Generates query using GSI:
```json
{
  "operation": "Query",
  "table_name": "Orders",
  "index_name": "StatusIndex",
  "key_condition_expression": "status = :status",
  "expression_attribute_values": {
    ":status": {"S": "pending"}
  }
}
```

2. Counts results
3. Returns: "There are 47 pending orders..."

### Example 3: Aggregation

**User:** "What's the total value of all delivered orders?"

**System Process:**
1. Queries all delivered orders
2. Calculates sum from results
3. Returns: "The total value of all delivered orders is $45,678.90"

## API Endpoints

### Chat Endpoint
```
POST /chat
```

Processes questions and returns analyzed results from DynamoDB.

### Schema Endpoint
```
GET /schema
```

Returns the current database schema configuration.

### Reload Config Endpoint
```
GET /reload-config
```

Reloads `system_prompt.txt` and `schema.json` without redeployment (useful for development).

## Supported DynamoDB Operations

The system supports the following DynamoDB operations:

1. **Query** - Efficient key-based queries
2. **Scan** - Full table scans (use sparingly)
3. **GetItem** - Retrieve single items by key
4. **BatchGetItem** - Retrieve multiple items efficiently

## Query JSON Format

The LLM generates queries in this format:

```json
{
  "operation": "Query|Scan|GetItem|BatchGetItem",
  "table_name": "TableName",
  "key_condition_expression": "pk = :pk_value",
  "expression_attribute_values": {
    ":pk_value": {"S": "value"}
  },
  "filter_expression": "attribute = :value",
  "projection_expression": "attr1, attr2, attr3",
  "index_name": "GSI-Name",
  "limit": 100,
  "expression_attribute_names": {
    "#attr": "reserved-keyword"
  }
}
```

## DynamoDB Data Types

When defining schemas, use these type codes:

- `S` - String
- `N` - Number
- `BOOL` - Boolean
- `L` - List
- `M` - Map
- `SS` - String Set
- `NS` - Number Set
- `BS` - Binary Set
- `B` - Binary

## Best Practices

### Schema Design

1. **Be Descriptive**: Provide clear descriptions for all attributes
2. **Document Indexes**: Explain what each GSI is used for
3. **Include Examples**: Add sample values in descriptions
4. **Keep Updated**: Update schema when table structure changes

### Query Optimization

1. **Use Indexes**: Define GSIs for common query patterns
2. **Limit Results**: Set reasonable limits to avoid timeouts
3. **Project Attributes**: Only retrieve necessary fields
4. **Prefer Query over Scan**: Use key-based queries when possible

### System Prompt

1. **Add Context**: Include business logic and rules
2. **Provide Examples**: Show example queries for your domain
3. **Set Boundaries**: Define what queries are appropriate
4. **Update Regularly**: Refine based on user interactions

## Troubleshooting

### Query Generation Issues

**Problem:** LLM generates invalid queries

**Solutions:**
- Ensure schema is accurate and complete
- Add more examples to system prompt
- Check that attribute names match exactly
- Verify data type definitions

### Execution Errors

**Problem:** DynamoDB query fails

**Solutions:**
- Verify IAM permissions
- Check table names are correct
- Ensure key conditions match table structure
- Validate expression attribute values

### Empty Results

**Problem:** Query returns no data

**Solutions:**
- Verify data exists in the table
- Check key condition expressions
- Review filter expressions
- Ensure correct index is being used

## Security Considerations

1. **IAM Policies**: Restrict DynamoDB access to specific tables
2. **Query Validation**: The system validates queries before execution
3. **Error Handling**: Errors are logged but not exposed with sensitive details
4. **Rate Limiting**: Consider implementing rate limits for expensive operations

## Performance Optimization

1. **Use Projections**: Only retrieve necessary attributes
2. **Leverage Indexes**: Create GSIs for common queries
3. **Set Limits**: Cap result set sizes
4. **Monitor Costs**: Track DynamoDB read capacity usage
5. **Cache Results**: Consider caching frequent queries

## Development Workflow

### Testing Locally

1. Configure AWS credentials with DynamoDB access
2. Update schema.json with test table
3. Run backend locally:
```bash
cd backend
export AWS_REGION=us-east-1
python main.py
```

4. Test queries via API

### Updating Schema

1. Edit `backend/schema.json`
2. Commit changes
3. Deploy backend:
```bash
./deploy.sh --skip-frontend
```

4. Or reload without deployment:
```bash
curl https://your-api-url/reload-config
```

## Monitoring

### CloudWatch Logs

View backend logs:
```bash
aws logs tail /ecs/ai-dms-chatbot-backend-dev --follow
```

### Query Inspection

The system logs:
- Generated queries
- Execution results
- Error messages
- Performance metrics

## Future Enhancements

Potential improvements:

- [ ] Query caching for performance
- [ ] Query cost estimation
- [ ] Multi-table joins
- [ ] Conversation context for follow-up queries
- [ ] Query history and favorites
- [ ] Export results to CSV/JSON
- [ ] Visual query builder
- [ ] Performance analytics dashboard

## Support

For issues related to:

- **Schema Configuration**: Review schema.json format
- **Query Generation**: Check system_prompt.txt
- **DynamoDB Access**: Verify IAM permissions
- **Deployment**: See main README.md

## Example Use Cases

### 1. Customer Service

"Show me all orders for customer X in the last 30 days"

### 2. Analytics

"What's the average order value by status?"

### 3. Operations

"List all pending shipments over $100"

### 4. Reporting

"How many orders were placed yesterday?"

### 5. Data Exploration

"What are the top 10 customers by order count?"

---

This workflow enables non-technical users to query complex databases using natural language, democratizing data access across your organization.

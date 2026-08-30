# MUI Component Patterns

## Page Layout

```tsx
<Box sx={{ p: 3 }}>
  <Typography variant="h4" component="h1" gutterBottom>
    Title
  </Typography>
  <Paper sx={{ p: 2 }}>{/* Content */}</Paper>
</Box>
```

## Filter Bar

```tsx
<Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
  <TextField label="Search" size="small" sx={{ minWidth: 200 }} />
  <Select label="Status" size="small" sx={{ minWidth: 150 }}>
    <MenuItem value="">All</MenuItem>
    <MenuItem value="active">Active</MenuItem>
  </Select>
  <Button variant="outlined">Clear Filters</Button>
</Stack>
```

## Empty State

```tsx
<Box sx={{ textAlign: 'center', py: 8 }}>
  <InboxIcon sx={{ fontSize: 64, color: 'text.secondary', mb: 2 }} />
  <Typography variant="h6" gutterBottom>
    No items found
  </Typography>
  <Typography color="text.secondary" sx={{ mb: 3 }}>
    Get started by creating your first item.
  </Typography>
  <Button variant="contained" startIcon={<AddIcon />}>
    Create Item
  </Button>
</Box>
```

## Loading Skeleton

```tsx
<TableBody>
  {[...Array(5)].map((_, i) => (
    <TableRow key={i}>
      <TableCell>
        <Skeleton variant="text" />
      </TableCell>
      <TableCell>
        <Skeleton variant="text" />
      </TableCell>
      <TableCell>
        <Skeleton variant="text" width="60%" />
      </TableCell>
    </TableRow>
  ))}
</TableBody>
```

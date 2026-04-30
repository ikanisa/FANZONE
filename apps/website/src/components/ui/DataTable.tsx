import { motion } from 'motion/react';

interface Column {
  header: string;
  accessor: string;
}

interface DataTableProps {
  columns: Column[];
  data: any[];
}

export function DataTable({ columns, data }: DataTableProps) {
  return (
    <div className="w-full overflow-x-auto rounded-3xl border border-outline-variant/15 bg-surface-container-lowest">
      <table className="w-full text-sm text-left">
        <thead className="text-xs text-muted uppercase tracking-widest border-b border-outline-variant/15">
          <tr>
            {columns.map((col, i) => (
              <th key={i} className="px-6 py-4">{col.header}</th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-outline-variant/15">
          {data.map((row, i) => (
            <tr key={i} className="hover:bg-surface-container-low transition-colors">
              {columns.map((col, j) => (
                <td key={j} className="px-6 py-4 font-mono text-text">{row[col.accessor]}</td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

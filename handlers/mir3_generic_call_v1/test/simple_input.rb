{
  'info' => {
    'username' => '',
    'password' => '',
    'endpoint' => 'https://inwebservices.mir3.com/services/mir3',
    'enable_debug_logging' => 'Yes'
  },
  'parameters' => {
    'error_handling' => 'Rasie Error',
    'output_type' => 'JSON',
    'action' => 'get_notification_reports_op',
    'xml' => 
      '<getNotificationReports>
        <apiVersion>4.14</apiVersion>
        <notificationReportUUID>04947c8b-0003-3000-80c0-fceb55463ffe</notificationReportUUID>
      </getNotificationReports>'
  }
}
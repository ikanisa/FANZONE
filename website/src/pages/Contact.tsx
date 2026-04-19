import { MessageCircle, Mail } from 'lucide-react';

export default function Contact() {
  return (
    <div className="section container max-w-3xl text-center">
      <h1 className="text-4xl font-bold mb-4">Support & Contact</h1>
      <p className="text-secondary mb-12">
        Have questions about the app, your wallet, or a prediction settlement? Get in touch with our team.
      </p>

      <div className="grid md:grid-cols-2 gap-8">
        <div className="glass-card flex-col items-center p-8">
          <MessageCircle size={48} className="text-accent mb-6" />
          <h3 className="text-2xl font-bold mb-2">WhatsApp Support</h3>
          <p className="text-secondary mb-6 text-sm">Fastest response time. Chat directly with the FANZONE operators.</p>
          <a href="https://wa.me/1234567890" target="_blank" rel="noreferrer" className="btn btn-accent w-full">Open Chat</a>
        </div>

        <div className="glass-card flex-col items-center p-8">
          <Mail size={48} className="text-secondary mb-6" />
          <h3 className="text-2xl font-bold mb-2">Email Support</h3>
          <p className="text-secondary mb-6 text-sm">For partnerships, data issues, or account deletion requests.</p>
          <a href="mailto:support@ikanisa.com" className="btn btn-outline w-full">Email Us</a>
        </div>
      </div>
    </div>
  );
}
